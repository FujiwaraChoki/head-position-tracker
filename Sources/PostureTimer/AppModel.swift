import Foundation
import Observation

enum ConnectionStatus {
    case connected, disconnected, denied

    var label: String {
        switch self {
        case .connected:    return "AirPods connected"
        case .disconnected: return "Put in AirPods to track posture"
        case .denied:       return "Motion access denied — enable in Privacy settings"
        }
    }

    var symbol: String {
        switch self {
        case .connected:    return "airpodspro"
        case .disconnected: return "airpods"
        case .denied:       return "exclamationmark.triangle"
        }
    }
}

/// Single observable view model that drives the whole UI. It owns the pomodoro
/// engine, the AirPods motion stream, the posture analyzer and the session
/// recorder, and republishes their state for SwiftUI.
@Observable
final class AppModel {

    let settings = Settings()

    @ObservationIgnored private let pomodoro = PomodoroTimer()
    @ObservationIgnored private let motion = MotionManager()
    @ObservationIgnored private let analyzer = PostureAnalyzer()
    @ObservationIgnored private let recorder = SessionRecorder()

    // Timer
    var mode: PomodoroMode = .focus
    var isRunning = false
    var remaining: TimeInterval = 25 * 60
    var progress: Double = 0
    var completedFocusSessions = 0
    var sessionsBeforeLongBreak = 4

    // Live posture
    var postureState: PostureState = .unknown
    var dropDegrees: Double?
    var postureScore: Double = 0
    var isCalibrating = false
    var isTracking = false
    var connection: ConnectionStatus = .disconnected

    // Session
    var chartSamples: [PostureSample] = []
    var goodFraction: Double = 0
    var averageScore: Double = 0
    var alertCount = 0
    var hasSessionData = false

    // Internal tracking bookkeeping
    @ObservationIgnored private var calibrationTimer: Timer?
    @ObservationIgnored private var poorSince: Date?
    @ObservationIgnored private var lastAlert: Date?
    @ObservationIgnored private var lastRecord: Date?
    @ObservationIgnored private var lastChartRefresh: Date?

    init() {
        pomodoro.delegate = self
        motion.delegate = self
        Notifier.requestAuthorization()
        applyTimerSettings()
        refreshConnection()
    }

    /// Push the configured timer durations into the engine. Called at launch and
    /// whenever a timer setting changes.
    func applyTimerSettings() {
        let wasIdleAtFull = !pomodoro.isRunning && pomodoro.isAtFullDuration
        pomodoro.focusDuration = settings.focusMinutes * 60
        pomodoro.shortBreakDuration = settings.shortBreakMinutes * 60
        pomodoro.longBreakDuration = settings.longBreakMinutes * 60
        pomodoro.sessionsBeforeLongBreak = max(1, settings.sessionsBeforeLongBreak)
        sessionsBeforeLongBreak = pomodoro.sessionsBeforeLongBreak
        if wasIdleAtFull {
            pomodoro.reset()   // snap an idle timer to the new full duration
        } else {
            refreshTimer()
        }
    }

    // MARK: - Derived display values

    var timeString: String {
        let secs = Int(ceil(max(0, remaining)))
        return String(format: "%02d:%02d", secs / 60, secs % 60)
    }

    var streakFilled: Int {
        guard sessionsBeforeLongBreak > 0 else { return 0 }
        return completedFocusSessions % sessionsBeforeLongBreak
    }

    var postureStatusText: String {
        isCalibrating ? "Calibrating…" : postureState.label
    }

    var postureDetailText: String {
        if isCalibrating { return "Sit tall and hold still." }
        guard let d = dropDegrees else { return "Waiting for AirPods motion…" }
        if d >= 0 { return String(format: "%.0f° below your upright baseline", d) }
        return String(format: "%.0f° above your upright baseline", -d)
    }

    // MARK: - User actions

    func toggle() { pomodoro.toggle() }

    func skip() { pomodoro.skip() }

    func reset() {
        pomodoro.reset()
        recorder.clear()
        analyzer.reset()
        poorSince = nil
        lastRecord = nil
        lastChartRefresh = nil
        postureState = .unknown
        dropDegrees = nil
        postureScore = 0
        isCalibrating = false
        refreshSession()
    }

    func recalibrate() {
        guard isTracking else { return }
        beginCalibration()
    }

    // MARK: - Tracking control

    private func updateMotionGating() {
        let shouldTrack = mode.isFocus && pomodoro.isRunning

        if shouldTrack && !isTracking {
            isTracking = true
            if pomodoro.isAtFullDuration {
                recorder.begin()
                analyzer.reset()
                lastRecord = nil
                lastChartRefresh = nil
                beginCalibration()
            } else if !analyzer.hasBaseline && !analyzer.isCalibrating {
                beginCalibration()
            }
            motion.startTracking()
        } else if !shouldTrack && isTracking {
            isTracking = false
            motion.stopTracking()
            cancelCalibration()
            poorSince = nil
            postureState = .unknown
            dropDegrees = nil
            postureScore = 0
            isCalibrating = false
        }

        refreshConnection()
    }

    private func beginCalibration() {
        analyzer.beginCalibration()
        isCalibrating = true
        postureState = .unknown
        dropDegrees = nil
        cancelCalibration()
        let t = Timer(timeInterval: settings.calibrationSeconds, repeats: false) { [weak self] _ in
            self?.analyzer.finishCalibration()
            self?.isCalibrating = false
        }
        RunLoop.main.add(t, forMode: .common)
        calibrationTimer = t
    }

    private func cancelCalibration() {
        calibrationTimer?.invalidate()
        calibrationTimer = nil
    }

    private func evaluateSlouch(state: PostureState, now: Date) {
        if state == .poor {
            if poorSince == nil { poorSince = now }
            let sustained = now.timeIntervalSince(poorSince!) >= settings.slouchGraceSeconds
            let cooled = lastAlert == nil || now.timeIntervalSince(lastAlert!) >= settings.alertCooldownSeconds
            if sustained && cooled {
                lastAlert = now
                recorder.registerAlert()
                Notifier.slouchAlert(sound: settings.soundEnabled,
                                     haptics: settings.hapticsEnabled,
                                     notify: settings.notificationsEnabled)
                refreshSession()
            }
        } else if state == .good {
            poorSince = nil
        }
    }

    // MARK: - Republishing engine state

    private func refreshTimer() {
        mode = pomodoro.mode
        isRunning = pomodoro.isRunning
        remaining = pomodoro.remaining
        progress = pomodoro.progress
        completedFocusSessions = pomodoro.completedFocusSessions
    }

    private func refreshConnection() {
        if motion.isAuthorizationDenied {
            connection = .denied
        } else if motion.isConnected {
            connection = .connected
        } else {
            connection = .disconnected
        }
    }

    private func refreshSession() {
        chartSamples = downsample(recorder.samples)
        goodFraction = recorder.goodFraction
        averageScore = recorder.averageScore
        alertCount = recorder.alertCount
        hasSessionData = !recorder.samples.isEmpty
    }

    private func downsample(_ samples: [PostureSample], max limit: Int = 240) -> [PostureSample] {
        guard samples.count > limit else { return samples }
        let step = samples.count / limit
        var out: [PostureSample] = []
        var i = 0
        while i < samples.count {
            out.append(samples[i])
            i += step
        }
        if let last = samples.last, out.last?.elapsed != last.elapsed { out.append(last) }
        return out
    }
}

// MARK: - PomodoroTimerDelegate

extension AppModel: PomodoroTimerDelegate {
    func pomodoroDidTick(_ timer: PomodoroTimer) {
        remaining = timer.remaining
        progress = timer.progress
    }

    func pomodoro(_ timer: PomodoroTimer, didComplete mode: PomodoroMode) {
        let message = mode.isFocus
            ? "Nice focus block. Time for a break."
            : "Break's over — back to it."
        Notifier.sessionDone(message, sound: settings.soundEnabled, notify: settings.notificationsEnabled)
    }

    func pomodoroDidChangeMode(_ timer: PomodoroTimer) {
        refreshTimer()
        updateMotionGating()
    }

    func pomodoroDidChangeRunState(_ timer: PomodoroTimer) {
        refreshTimer()
        updateMotionGating()
    }
}

// MARK: - MotionManagerDelegate

extension AppModel: MotionManagerDelegate {
    func motionManager(_ manager: MotionManager, didUpdatePitch pitch: Double, roll: Double, yaw: Double) {
        analyzer.addSample(pitch: pitch)
        guard isTracking else { return }

        analyzer.fairThresholdDeg = settings.fairThresholdDeg
        analyzer.poorThresholdDeg = settings.poorThresholdDeg
        analyzer.invertPitch = settings.invertPitch

        if analyzer.isCalibrating {
            isCalibrating = true
            dropDegrees = nil
            return
        }
        isCalibrating = false

        let state = analyzer.state
        postureState = state
        dropDegrees = analyzer.dropDegrees
        postureScore = analyzer.score

        let now = Date()
        if lastRecord == nil || now.timeIntervalSince(lastRecord!) >= 0.25 {
            recorder.record(score: analyzer.score, state: state)
            lastRecord = now
        }
        if lastChartRefresh == nil || now.timeIntervalSince(lastChartRefresh!) >= 1.0 {
            refreshSession()
            lastChartRefresh = now
        }

        evaluateSlouch(state: state, now: now)
    }

    func motionManager(_ manager: MotionManager, connectionDidChange connected: Bool) {
        refreshConnection()
    }

    func motionManagerDidDenyAuthorization(_ manager: MotionManager) {
        refreshConnection()
    }
}
