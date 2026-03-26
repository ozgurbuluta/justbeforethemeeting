import Foundation

/// A calendar event that will (or would) start the pre-meeting countdown at `triggerDate`
/// (`meeting start − advance warning`).
struct UpcomingCountdownItem: Identifiable, Hashable {
    var id: String { "\(event.id)|\(event.start.timeIntervalSince1970)" }
    let event: CalendarEvent
    let triggerDate: Date
}

extension SettingsManager {
    func upcomingCountdownItems(from events: [CalendarEvent], now: Date = Date(), limit: Int = 15) -> [UpcomingCountdownItem] {
        let advance = max(1, advanceWarningSeconds)
        return events
            .filter { passesFilter($0) && $0.start > now }
            .sorted { $0.start < $1.start }
            .prefix(limit)
            .map { UpcomingCountdownItem(event: $0, triggerDate: $0.start.addingTimeInterval(-TimeInterval(advance))) }
    }

    func nextUpcomingFilteredEvent(from events: [CalendarEvent], now: Date = Date()) -> CalendarEvent? {
        events
            .filter { passesFilter($0) && $0.start > now }
            .min { $0.start < $1.start }
    }
}
