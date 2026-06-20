import SwiftUI

/// How the user's head is oriented relative to their calibrated upright baseline.
enum PostureState {
    case unknown   // not enough data yet / not tracking
    case good      // upright
    case fair      // starting to drift
    case poor      // slouching

    var label: String {
        switch self {
        case .unknown: return "No reading"
        case .good:    return "Upright"
        case .fair:    return "Drifting"
        case .poor:    return "Slouching"
        }
    }

    var color: Color {
        switch self {
        case .unknown: return .secondary
        case .good:    return .green
        case .fair:    return .orange
        case .poor:    return .red
        }
    }

    var symbol: String {
        switch self {
        case .unknown: return "questionmark.circle"
        case .good:    return "checkmark.circle.fill"
        case .fair:    return "exclamationmark.triangle.fill"
        case .poor:    return "exclamationmark.octagon.fill"
        }
    }
}
