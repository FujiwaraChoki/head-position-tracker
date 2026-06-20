import CoreMotion
import Foundation

protocol MotionManagerDelegate: AnyObject {
    func motionManager(_ manager: MotionManager, didUpdatePitch pitch: Double, roll: Double, yaw: Double)
    func motionManager(_ manager: MotionManager, connectionDidChange connected: Bool)
    func motionManagerDidDenyAuthorization(_ manager: MotionManager)
}

/// Thin wrapper over `CMHeadphoneMotionManager` — the same sensors that power
/// Spatial Audio. No extra permission beyond Motion & Fitness, and the IMU is
/// already running whenever the AirPods are in your ears.
final class MotionManager: NSObject, CMHeadphoneMotionManagerDelegate {

    weak var delegate: MotionManagerDelegate?

    private let manager = CMHeadphoneMotionManager()
    private var wantsUpdates = false
    private(set) var isStreaming = false

    var isSupported: Bool { /* device motion path exists on this build of macOS */ true }
    var isAuthorizationDenied: Bool { CMHeadphoneMotionManager.authorizationStatus() == .denied }

    /// Whether compatible headphones are currently connected and feeding motion.
    var isConnected: Bool { manager.isDeviceMotionAvailable }

    override init() {
        super.init()
        manager.delegate = self
    }

    /// Begin (or arm) head-motion tracking. If the AirPods aren't connected yet,
    /// we remember the intent and start the moment they connect.
    func startTracking() {
        wantsUpdates = true
        guard !isStreaming else { return }
        if isAuthorizationDenied {
            delegate?.motionManagerDidDenyAuthorization(self)
            return
        }
        guard manager.isDeviceMotionAvailable else { return } // resumes via didConnect
        beginUpdates()
    }

    func stopTracking() {
        wantsUpdates = false
        guard isStreaming else { return }
        manager.stopDeviceMotionUpdates()
        isStreaming = false
    }

    private func beginUpdates() {
        guard !isStreaming else { return }
        isStreaming = true
        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
            guard let self else { return }
            if error != nil {
                if self.isAuthorizationDenied {
                    self.delegate?.motionManagerDidDenyAuthorization(self)
                }
                return
            }
            guard let motion else { return }
            let a = motion.attitude
            self.delegate?.motionManager(self, didUpdatePitch: a.pitch, roll: a.roll, yaw: a.yaw)
        }
    }

    // MARK: - CMHeadphoneMotionManagerDelegate

    func headphoneMotionManagerDidConnect(_ manager: CMHeadphoneMotionManager) {
        delegate?.motionManager(self, connectionDidChange: true)
        if wantsUpdates && !isStreaming { beginUpdates() }
    }

    func headphoneMotionManagerDidDisconnect(_ manager: CMHeadphoneMotionManager) {
        delegate?.motionManager(self, connectionDidChange: false)
        if isStreaming {
            manager.stopDeviceMotionUpdates()
            isStreaming = false
        }
    }
}
