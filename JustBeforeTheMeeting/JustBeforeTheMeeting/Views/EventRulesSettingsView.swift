import SwiftUI

struct EventRulesSettingsView: View {
    @EnvironmentObject private var settings: SettingsManager
    @EnvironmentObject private var calendar: GoogleCalendarService

    var body: some View {
        Form {
            Section(L10n.s("events.section.rules")) {
                Picker(L10n.s("events.which_events"), selection: $settings.eventFilterMode) {
                    ForEach(EventFilterMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                if settings.eventFilterMode == .keyword {
                    TextField(L10n.s("events.keyword_placeholder"), text: $settings.keywordFilter)
                }
            }

            Section(L10n.s("events.section.upcoming")) {
                if calendar.events.isEmpty {
                    Text(L10n.s("events.empty_hint"))
                        .foregroundStyle(.secondary)
                } else {
                    List(Array(calendar.events.prefix(40))) { event in
                        Toggle(isOn: binding(for: event)) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(event.title)
                                    .font(.headline)
                                Text(event.start.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .frame(minHeight: 200)
                }
            }
        }
        .formStyle(.grouped)
    }

    private func binding(for event: CalendarEvent) -> Binding<Bool> {
        Binding(
            get: { settings.passesFilter(event) },
            set: { newValue in
                let rule = settings.rulePasses(event)
                if newValue == rule {
                    var next = settings.eventOverrides
                    next.removeValue(forKey: event.id)
                    settings.eventOverrides = next
                } else {
                    settings.eventOverrides[event.id] = newValue
                }
            }
        )
    }
}
