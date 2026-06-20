import AppKit
import UserNotifications

/// Best-effort alerting. Sound + haptics always work; system notifications only
/// when we're running from a signed .app bundle (a bundle identifier exists).
enum Notifier {

    private static let bundled = Bundle.main.bundleIdentifier != nil

    static func requestAuthorization() {
        guard bundled else { return }
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    static func slouchAlert(sound: Bool, haptics: Bool, notify: Bool) {
        if sound { playSound("Sosumi") }
        if haptics { haptic() }
        if notify { post(title: "Sit up", body: "Your head dropped — straighten your back.") }
    }

    static func sessionDone(_ message: String, sound: Bool, notify: Bool) {
        if sound { playSound("Glass") }
        if notify { post(title: "Pomodoro complete", body: message) }
    }

    private static func post(title: String, body: String) {
        guard bundled else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let req = UNNotificationRequest(identifier: UUID().uuidString,
                                        content: content, trigger: nil)
        UNUserNotificationCenter.current().add(req, withCompletionHandler: nil)
    }

    private static func playSound(_ name: String) {
        NSSound(named: NSSound.Name(name))?.play()
    }

    private static func haptic() {
        NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
    }
}
