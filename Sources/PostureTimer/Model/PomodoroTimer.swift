import Foundation

enum PomodoroMode {
    case focus, shortBreak, longBreak

    var title: String {
        switch self {
        case .focus:      return "FOCUS"
        case .shortBreak: return "SHORT BREAK"
        case .longBreak:  return "LONG BREAK"
        }
    }

    var isFocus: Bool { self == .focus }
}

protocol PomodoroTimerDelegate: AnyObject {
    func pomodoroDidTick(_ timer: PomodoroTimer)
    func pomodoro(_ timer: PomodoroTimer, didComplete mode: PomodoroMode)
    func pomodoroDidChangeMode(_ timer: PomodoroTimer)
    func pomodoroDidChangeRunState(_ timer: PomodoroTimer)
}

/// A classic Pomodoro state machine: focus → short break → … → long break.
/// Uses a wall-clock deadline so it stays accurate across pauses.
final class PomodoroTimer {

    weak var delegate: PomodoroTimerDelegate?

    var focusDuration: TimeInterval = 25 * 60
    var shortBreakDuration: TimeInterval = 5 * 60
    var longBreakDuration: TimeInterval = 15 * 60
    var sessionsBeforeLongBreak = 4

    private(set) var mode: PomodoroMode = .focus
    private(set) var isRunning = false
    private(set) var completedFocusSessions = 0

    private var remainingWhenPaused: TimeInterval
    private var deadline: Date?
    private var ticker: Timer?

    init() {
        remainingWhenPaused = focusDuration
    }

    func duration(for mode: PomodoroMode) -> TimeInterval {
        switch mode {
        case .focus:      return focusDuration
        case .shortBreak: return shortBreakDuration
        case .longBreak:  return longBreakDuration
        }
    }

    var totalDuration: TimeInterval { duration(for: mode) }

    var remaining: TimeInterval {
        if isRunning, let deadline {
            return max(0, deadline.timeIntervalSinceNow)
        }
        return remainingWhenPaused
    }

    var progress: Double {
        guard totalDuration > 0 else { return 0 }
        return min(1, max(0, 1 - remaining / totalDuration))
    }

    /// True the moment a fresh session is about to start (used to trigger
    /// recalibration on a brand-new focus block).
    var isAtFullDuration: Bool {
        abs(remaining - totalDuration) < 0.5
    }

    // MARK: - Controls

    func toggle() { isRunning ? pause() : start() }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        deadline = Date().addingTimeInterval(remainingWhenPaused)
        startTicker()
        delegate?.pomodoroDidChangeRunState(self)
    }

    func pause() {
        guard isRunning else { return }
        remainingWhenPaused = remaining
        isRunning = false
        stopTicker()
        delegate?.pomodoroDidChangeRunState(self)
    }

    /// Stop and reset the *current* mode back to its full duration.
    func reset() {
        stopTicker()
        isRunning = false
        remainingWhenPaused = totalDuration
        deadline = nil
        delegate?.pomodoroDidChangeRunState(self)
        delegate?.pomodoroDidTick(self)
    }

    /// Skip to the next mode in the cycle without completing the current one.
    func skip() {
        advanceMode(countCompletion: false)
    }

    private func startTicker() {
        stopTicker()
        let t = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in self?.fire() }
        RunLoop.main.add(t, forMode: .common)
        ticker = t
    }

    private func stopTicker() {
        ticker?.invalidate()
        ticker = nil
    }

    private func fire() {
        delegate?.pomodoroDidTick(self)
        if remaining <= 0 {
            let finished = mode
            stopTicker()
            isRunning = false
            delegate?.pomodoro(self, didComplete: finished)
            advanceMode(countCompletion: true)
        }
    }

    private func advanceMode(countCompletion: Bool) {
        let wasFocus = mode.isFocus
        if countCompletion && wasFocus {
            completedFocusSessions += 1
        }

        switch mode {
        case .focus:
            let due = completedFocusSessions % sessionsBeforeLongBreak == 0 && completedFocusSessions > 0
            mode = due ? .longBreak : .shortBreak
        case .shortBreak, .longBreak:
            mode = .focus
        }

        isRunning = false
        remainingWhenPaused = totalDuration
        deadline = nil
        delegate?.pomodoroDidChangeMode(self)
        delegate?.pomodoroDidChangeRunState(self)
        delegate?.pomodoroDidTick(self)
    }
}
