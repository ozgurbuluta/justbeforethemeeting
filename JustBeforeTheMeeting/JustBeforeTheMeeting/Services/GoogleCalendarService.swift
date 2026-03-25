import Combine
import Foundation

@MainActor
final class GoogleCalendarService: ObservableObject {
    @Published private(set) var events: [CalendarEvent] = []
    @Published private(set) var lastSync: Date?
    @Published private(set) var lastError: String?

    private let settings: SettingsManager
    private let oauth: OAuthManager
    private var pollTask: Task<Void, Never>?

    init(settings: SettingsManager, oauth: OAuthManager) {
        self.settings = settings
        self.oauth = oauth
    }

    deinit {
        pollTask?.cancel()
    }

    func refreshEvents() async {
        lastError = nil
        guard oauth.isAuthorized else {
            events = []
            return
        }
        do {
            let token = try await oauth.accessToken()
            let list = try await fetchCalendarList(accessToken: token)
            var merged: [CalendarEvent] = []
            let now = Date()
            let horizon = Calendar.current.date(byAdding: .hour, value: 48, to: now) ?? now.addingTimeInterval(86400 * 2)
            for cal in list where cal.selected != false && cal.hidden != true {
                let encoded = Self.pathEncodeCalendarId(cal.id)
                let evs = try await fetchEvents(calendarId: encoded, accessToken: token, from: now, to: horizon)
                merged.append(contentsOf: evs)
            }
            merged.sort { $0.start < $1.start }
            events = merged
            lastSync = Date()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func startPollingIfNeeded() {
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                let interval = await MainActor.run { self.settings.calendarPollIntervalSeconds }
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                if Task.isCancelled { break }
                await self.refreshEvents()
            }
        }
    }

    func stopPolling() {
        pollTask?.cancel()
        pollTask = nil
    }

    // MARK: - API

    /// Percent-encodes a calendar ID for use in the Calendar API path (handles `@`, `#`, spaces, etc.).
    private static func pathEncodeCalendarId(_ id: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._~"))
        return id.addingPercentEncoding(withAllowedCharacters: allowed) ?? id
    }

    private struct CalendarListResponse: Decodable {
        struct Item: Decodable {
            var id: String
            var selected: Bool?
            var hidden: Bool?
        }
        var items: [Item]?
    }

    private struct EventsResponse: Decodable {
        struct Item: Decodable {
            var id: String
            var summary: String?
            var htmlLink: String?
            var hangoutLink: String?
            var start: TimeField?
            var end: TimeField?
        }
        struct TimeField: Decodable {
            var dateTime: String?
            var date: String?
        }
        var items: [Item]?
    }

    private func fetchCalendarList(accessToken: String) async throws -> [CalendarListResponse.Item] {
        var components = URLComponents(string: "https://www.googleapis.com/calendar/v3/users/me/calendarList")!
        components.queryItems = [URLQueryItem(name: "maxResults", value: "250")]
        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200 ..< 300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        let decoded = try JSONDecoder().decode(CalendarListResponse.self, from: data)
        return decoded.items ?? []
    }

    private func fetchEvents(calendarId: String, accessToken: String, from: Date, to: Date) async throws -> [CalendarEvent] {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]

        var components = URLComponents(
            string: "https://www.googleapis.com/calendar/v3/calendars/\(calendarId)/events"
        )!
        components.queryItems = [
            URLQueryItem(name: "singleEvents", value: "true"),
            URLQueryItem(name: "orderBy", value: "startTime"),
            URLQueryItem(name: "timeMin", value: formatter.string(from: from)),
            URLQueryItem(name: "timeMax", value: formatter.string(from: to))
        ]

        guard let url = components.url else { return [] }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200 ..< 300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let decoded = try JSONDecoder().decode(EventsResponse.self, from: data)
        let parseWithFraction = ISO8601DateFormatter()
        parseWithFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let parsePlain = ISO8601DateFormatter()
        parsePlain.formatOptions = [.withInternetDateTime]

        func parseDateTime(_ string: String) -> Date? {
            parseWithFraction.date(from: string)
                ?? parsePlain.date(from: string)
                ?? ISO8601DateFormatter().date(from: string)
        }

        let dateOnlyFormatter = DateFormatter()
        dateOnlyFormatter.calendar = Calendar(identifier: .gregorian)
        dateOnlyFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateOnlyFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        dateOnlyFormatter.dateFormat = "yyyy-MM-dd"

        return (decoded.items ?? []).compactMap { item -> CalendarEvent? in
            let start: Date?
            if let dt = item.start?.dateTime {
                start = parseDateTime(dt)
            } else if let d = item.start?.date {
                start = dateOnlyFormatter.date(from: d)
            } else {
                start = nil
            }
            let end: Date?
            if let dt = item.end?.dateTime {
                end = parseDateTime(dt)
            } else if let d = item.end?.date {
                end = dateOnlyFormatter.date(from: d)
            } else {
                end = nil
            }
            guard let s = start else { return nil }
            let e = end ?? s.addingTimeInterval(3600)
            return CalendarEvent(
                id: "\(calendarId)|\(item.id)",
                title: item.summary ?? "(No title)",
                start: s,
                end: e,
                calendarId: calendarId,
                htmlLink: item.htmlLink,
                hangoutLink: item.hangoutLink,
                conferenceData: nil
            )
        }
    }
}
