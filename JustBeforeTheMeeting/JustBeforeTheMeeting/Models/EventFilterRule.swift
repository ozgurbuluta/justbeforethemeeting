import Foundation

enum EventFilterMode: String, CaseIterable, Identifiable, Codable {
    case all
    case videoOnly
    case keyword

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .all: return L10n.s("filter.all_events")
        case .videoOnly: return L10n.s("filter.video_only")
        case .keyword: return L10n.s("filter.keyword")
        }
    }
}
