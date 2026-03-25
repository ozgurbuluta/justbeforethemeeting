import Combine
import Foundation
import ServiceManagement

@MainActor
final class SettingsManager: ObservableObject {
    @Published var customSoundPath: String? {
        didSet { UserDefaults.standard.set(customSoundPath, forKey: Keys.customSoundPath) }
    }

    @Published var volume: Double {
        didSet { UserDefaults.standard.set(volume, forKey: Keys.volume) }
    }

    @Published var countdownDurationSeconds: Int {
        didSet { UserDefaults.standard.set(countdownDurationSeconds, forKey: Keys.countdownDuration) }
    }

    @Published var advanceWarningSeconds: Int {
        didSet { UserDefaults.standard.set(advanceWarningSeconds, forKey: Keys.advanceWarning) }
    }

    @Published var eventFilterMode: EventFilterMode {
        didSet { UserDefaults.standard.set(eventFilterMode.rawValue, forKey: Keys.eventFilterMode) }
    }

    @Published var keywordFilter: String {
        didSet { UserDefaults.standard.set(keywordFilter, forKey: Keys.keywordFilter) }
    }

    @Published var eventOverrides: [String: Bool] {
        didSet {
            if let data = try? JSONEncoder().encode(eventOverrides) {
                UserDefaults.standard.set(data, forKey: Keys.eventOverrides)
            }
        }
    }

    @Published var calendarPollIntervalSeconds: TimeInterval {
        didSet { UserDefaults.standard.set(calendarPollIntervalSeconds, forKey: Keys.pollInterval) }
    }

    @Published var backupNotificationsEnabled: Bool {
        didSet { UserDefaults.standard.set(backupNotificationsEnabled, forKey: Keys.backupNotifications) }
    }

    private enum Keys {
        static let customSoundPath = "jbtm.customSoundPath"
        static let volume = "jbtm.volume"
        static let countdownDuration = "jbtm.countdownDuration"
        static let advanceWarning = "jbtm.advanceWarning"
        static let eventFilterMode = "jbtm.eventFilterMode"
        static let keywordFilter = "jbtm.keywordFilter"
        static let eventOverrides = "jbtm.eventOverrides"
        static let pollInterval = "jbtm.pollInterval"
        static let backupNotifications = "jbtm.backupNotifications"
    }

    init() {
        let defaults = UserDefaults.standard
        customSoundPath = defaults.string(forKey: Keys.customSoundPath)
        volume = defaults.object(forKey: Keys.volume) as? Double ?? 0.85
        countdownDurationSeconds = defaults.object(forKey: Keys.countdownDuration) as? Int ?? 30
        advanceWarningSeconds = defaults.object(forKey: Keys.advanceWarning) as? Int ?? 30
        if let raw = defaults.string(forKey: Keys.eventFilterMode),
           let mode = EventFilterMode(rawValue: raw) {
            eventFilterMode = mode
        } else {
            eventFilterMode = .all
        }
        keywordFilter = defaults.string(forKey: Keys.keywordFilter) ?? ""
        if let data = defaults.data(forKey: Keys.eventOverrides),
           let decoded = try? JSONDecoder().decode([String: Bool].self, from: data) {
            eventOverrides = decoded
        } else {
            eventOverrides = [:]
        }
        calendarPollIntervalSeconds = defaults.object(forKey: Keys.pollInterval) as? TimeInterval ?? 300
        backupNotificationsEnabled = defaults.object(forKey: Keys.backupNotifications) as? Bool ?? true
    }

    func isLaunchAtLoginEnabled() -> Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        }
        return false
    }

    func setLaunchAtLogin(_ enabled: Bool) throws {
        if #available(macOS 13.0, *) {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        }
    }

    func rulePasses(_ event: CalendarEvent) -> Bool {
        switch eventFilterMode {
        case .all:
            return true
        case .videoOnly:
            return event.hasVideoLink
        case .keyword:
            let k = keywordFilter.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !k.isEmpty else { return true }
            return event.title.localizedCaseInsensitiveContains(k)
        }
    }

    func passesFilter(_ event: CalendarEvent) -> Bool {
        if let override = eventOverrides[event.id] {
            return override
        }
        return rulePasses(event)
    }
}
