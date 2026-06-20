import Foundation
import Observation

/// Everything the user can configure, persisted to `UserDefaults`. Both the
/// Settings window (via `@Bindable`) and the engine read this single instance.
@Observable
final class Settings {

    @ObservationIgnored private let defaults = UserDefaults.standard

    // Timer (minutes / count)
    var focusMinutes: Double          { didSet { defaults.set(focusMinutes, forKey: "focusMinutes") } }
    var shortBreakMinutes: Double     { didSet { defaults.set(shortBreakMinutes, forKey: "shortBreakMinutes") } }
    var longBreakMinutes: Double      { didSet { defaults.set(longBreakMinutes, forKey: "longBreakMinutes") } }
    var sessionsBeforeLongBreak: Int  { didSet { defaults.set(sessionsBeforeLongBreak, forKey: "sessionsBeforeLongBreak") } }

    // Posture detection
    var fairThresholdDeg: Double {
        didSet {
            if fairThresholdDeg > poorThresholdDeg { poorThresholdDeg = fairThresholdDeg }
            defaults.set(fairThresholdDeg, forKey: "fairThresholdDeg")
        }
    }
    var poorThresholdDeg: Double {
        didSet {
            if poorThresholdDeg < fairThresholdDeg { fairThresholdDeg = poorThresholdDeg }
            defaults.set(poorThresholdDeg, forKey: "poorThresholdDeg")
        }
    }
    var calibrationSeconds: Double    { didSet { defaults.set(calibrationSeconds, forKey: "calibrationSeconds") } }
    var invertPitch: Bool             { didSet { defaults.set(invertPitch, forKey: "invertPitch") } }

    // Alerts
    var slouchGraceSeconds: Double    { didSet { defaults.set(slouchGraceSeconds, forKey: "slouchGraceSeconds") } }
    var alertCooldownSeconds: Double  { didSet { defaults.set(alertCooldownSeconds, forKey: "alertCooldownSeconds") } }
    var soundEnabled: Bool            { didSet { defaults.set(soundEnabled, forKey: "soundEnabled") } }
    var hapticsEnabled: Bool          { didSet { defaults.set(hapticsEnabled, forKey: "hapticsEnabled") } }
    var notificationsEnabled: Bool    { didSet { defaults.set(notificationsEnabled, forKey: "notificationsEnabled") } }

    init() {
        let d = defaults
        func dbl(_ key: String, _ fallback: Double) -> Double {
            d.object(forKey: key) != nil ? d.double(forKey: key) : fallback
        }
        func int(_ key: String, _ fallback: Int) -> Int {
            d.object(forKey: key) != nil ? d.integer(forKey: key) : fallback
        }
        func bool(_ key: String, _ fallback: Bool) -> Bool {
            d.object(forKey: key) != nil ? d.bool(forKey: key) : fallback
        }

        // didSet is not invoked for assignments during init, so defaults stay as-is.
        focusMinutes = dbl("focusMinutes", 25)
        shortBreakMinutes = dbl("shortBreakMinutes", 5)
        longBreakMinutes = dbl("longBreakMinutes", 15)
        sessionsBeforeLongBreak = int("sessionsBeforeLongBreak", 4)
        fairThresholdDeg = dbl("fairThresholdDeg", 9)
        poorThresholdDeg = dbl("poorThresholdDeg", 18)
        calibrationSeconds = dbl("calibrationSeconds", 2.5)
        invertPitch = bool("invertPitch", false)
        slouchGraceSeconds = dbl("slouchGraceSeconds", 6)
        alertCooldownSeconds = dbl("alertCooldownSeconds", 25)
        soundEnabled = bool("soundEnabled", true)
        hapticsEnabled = bool("hapticsEnabled", true)
        notificationsEnabled = bool("notificationsEnabled", true)
    }

    /// A value that changes whenever a timer-affecting setting changes, so the
    /// UI can re-apply durations to the engine via `.onChange`.
    var timerConfigToken: String {
        "\(focusMinutes)|\(shortBreakMinutes)|\(longBreakMinutes)|\(sessionsBeforeLongBreak)"
    }

    func restoreDefaults() {
        focusMinutes = 25
        shortBreakMinutes = 5
        longBreakMinutes = 15
        sessionsBeforeLongBreak = 4
        poorThresholdDeg = 18
        fairThresholdDeg = 9
        calibrationSeconds = 2.5
        invertPitch = false
        slouchGraceSeconds = 6
        alertCooldownSeconds = 25
        soundEnabled = true
        hapticsEnabled = true
        notificationsEnabled = true
    }
}
