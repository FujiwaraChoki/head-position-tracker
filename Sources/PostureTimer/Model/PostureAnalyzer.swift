import Foundation

/// Turns a raw stream of head-pitch readings into a posture state.
///
/// Model: when you slouch at a desk your head drops forward and your chin
/// tucks down, which lowers the AirPods' reported pitch. We capture an upright
/// baseline during calibration, then measure how far the (smoothed) live pitch
/// has dropped below it. The drop, in degrees, is what drives the state.
final class PostureAnalyzer {

    // Thresholds, in degrees of forward head drop from baseline.
    var fairThresholdDeg: Double = 9
    var poorThresholdDeg: Double = 18

    /// Flip the drop sign, in case this AirPods model reports pitch the other way.
    var invertPitch: Bool = false

    // Low-pass smoothing factor (0…1). Lower = smoother but laggier.
    private let smoothing = 0.18

    private var smoothedPitch: Double?
    private(set) var baselinePitch: Double?

    private var calibrating = false
    private var calibrationSamples: [Double] = []

    var hasBaseline: Bool { baselinePitch != nil }
    var isCalibrating: Bool { calibrating }

    /// The smoothed live pitch, in radians.
    var currentPitch: Double? { smoothedPitch }

    /// How far the head has dropped below baseline, in degrees.
    /// Positive = slouching forward/down. Negative = leaning back / looking up.
    var dropDegrees: Double? {
        guard let base = baselinePitch, let cur = smoothedPitch else { return nil }
        let raw = base - cur
        return (invertPitch ? -raw : raw) * 180 / .pi
    }

    func reset() {
        smoothedPitch = nil
        baselinePitch = nil
        calibrating = false
        calibrationSamples.removeAll()
    }

    func beginCalibration() {
        calibrating = true
        calibrationSamples.removeAll()
        baselinePitch = nil
    }

    func finishCalibration() {
        calibrating = false
        guard !calibrationSamples.isEmpty else { return }
        baselinePitch = calibrationSamples.reduce(0, +) / Double(calibrationSamples.count)
        calibrationSamples.removeAll()
    }

    /// Feed one raw pitch reading (radians) from the motion stream.
    func addSample(pitch: Double) {
        if let s = smoothedPitch {
            smoothedPitch = s + smoothing * (pitch - s)
        } else {
            smoothedPitch = pitch
        }
        if calibrating, let s = smoothedPitch {
            calibrationSamples.append(s)
        }
    }

    var state: PostureState {
        guard let drop = dropDegrees else { return .unknown }
        if drop >= poorThresholdDeg { return .poor }
        if drop >= fairThresholdDeg { return .fair }
        return .good
    }

    /// A 0…100 "uprightness" score for charting. 100 = perfectly upright.
    var score: Double {
        guard let drop = dropDegrees else { return 0 }
        let d = max(0, drop)               // looking up doesn't lower the score
        return max(0, min(100, 100 - d * 4)) // 0 at a 25° forward drop
    }
}
