import Foundation

struct PostureSample {
    let elapsed: TimeInterval   // seconds since the focus session began
    let score: Double           // 0…100 uprightness
    let state: PostureState
}

/// Records the posture trace of a single focus session and derives the
/// session-level stats shown to the user.
final class SessionRecorder {

    private(set) var samples: [PostureSample] = []
    private(set) var alertCount = 0
    private var startDate: Date?

    var isRecording: Bool { startDate != nil }

    func begin() {
        samples.removeAll()
        alertCount = 0
        startDate = Date()
    }

    func stop() {
        startDate = nil
    }

    func clear() {
        samples.removeAll()
        alertCount = 0
        startDate = nil
    }

    func record(score: Double, state: PostureState) {
        guard let startDate else { return }
        samples.append(PostureSample(elapsed: Date().timeIntervalSince(startDate),
                                     score: score, state: state))
    }

    func registerAlert() { alertCount += 1 }

    // MARK: - Aggregates

    private func fraction(_ predicate: (PostureState) -> Bool) -> Double {
        let tracked = samples.filter { $0.state != .unknown }
        guard !tracked.isEmpty else { return 0 }
        let n = tracked.filter { predicate($0.state) }.count
        return Double(n) / Double(tracked.count)
    }

    var goodFraction: Double { fraction { $0 == .good } }
    var slouchFraction: Double { fraction { $0 == .poor } }

    var averageScore: Double {
        let tracked = samples.filter { $0.state != .unknown }
        guard !tracked.isEmpty else { return 0 }
        return tracked.map(\.score).reduce(0, +) / Double(tracked.count)
    }
}
