import Foundation

enum EventFilterMode: String, CaseIterable, Identifiable, Codable {
    case all
    case videoOnly
    case keyword

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .all: return "All events"
        case .videoOnly: return "Only events with video links"
        case .keyword: return "Only events matching keyword"
        }
    }
}
