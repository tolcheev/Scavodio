import Foundation

/// Chunk size presets for the Split feature.
enum SplitDuration: String, CaseIterable, Identifiable {
    case thirtyMin  = "30m"
    case oneHour    = "1h"
    case twoHours   = "2h"
    case threeHours = "3h"
    case fourHours  = "4h"
    case sixHours   = "6h"

    var id: String { rawValue }

    var label: String { rawValue }

    var seconds: TimeInterval {
        switch self {
        case .thirtyMin:  return 30 * 60
        case .oneHour:    return 60 * 60
        case .twoHours:   return 2 * 60 * 60
        case .threeHours: return 3 * 60 * 60
        case .fourHours:  return 4 * 60 * 60
        case .sixHours:   return 6 * 60 * 60
        }
    }
}
