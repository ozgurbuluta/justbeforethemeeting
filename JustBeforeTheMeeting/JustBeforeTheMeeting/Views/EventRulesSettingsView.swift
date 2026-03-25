import SwiftUI

struct EventRulesSettingsView: View {
    @EnvironmentObject private var settings: SettingsManager
    @EnvironmentObject private var calendar: GoogleCalendarService

    var body: some View {
        Form {
            Section("Rules") {
                Picker("Which events", selection: $settings.eventFilterMode) {
                    ForEach(EventFilterMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                if settings.eventFilterMode == .keyword {
                    TextField("Keyword in title", text: $settings.keywordFilter)
                }
            }

            Section("Upcoming (per-event override)") {
                if calendar.events.isEmpty {
                    Text("Connect Google Calendar and sync to see events.")
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
