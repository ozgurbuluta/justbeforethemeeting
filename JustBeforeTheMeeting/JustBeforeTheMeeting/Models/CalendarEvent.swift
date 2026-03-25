import Foundation

struct CalendarEvent: Identifiable, Hashable, Codable {
    var id: String
    var title: String
    var start: Date
    var end: Date
    var calendarId: String
    var htmlLink: String?
    var hangoutLink: String?
    var conferenceData: String?

    var hasVideoLink: Bool {
        if hangoutLink != nil { return true }
        if let c = conferenceData, !c.isEmpty { return true }
        if let h = htmlLink, h.contains("meet.google.com") { return true }
        return false
    }
}
