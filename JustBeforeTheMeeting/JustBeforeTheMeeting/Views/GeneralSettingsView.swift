import SwiftUI

struct GeneralSettingsView: View {
    @EnvironmentObject private var settings: SettingsManager
    @State private var launchAtLogin = false
    @State private var launchError: String?

    var body: some View {
        Form {
            Section("Countdown") {
                Stepper(value: $settings.countdownDurationSeconds, in: 5 ... 300, step: 5) {
                    Text("Countdown length: **\(settings.countdownDurationSeconds)s**")
                }
                Stepper(value: $settings.advanceWarningSeconds, in: 5 ... 300, step: 5) {
                    Text("Advance warning: **\(settings.advanceWarningSeconds)s** before start")
                }
                Text("Music and the menu bar timer run for the shorter of countdown length and time until the event starts.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Calendar refresh") {
                Picker("Poll interval", selection: $settings.calendarPollIntervalSeconds) {
                    Text("1 min").tag(60.0)
                    Text("5 min").tag(300.0)
                    Text("15 min").tag(900.0)
                }
            }

            Section("Notifications") {
                Toggle("Backup notification when countdown starts", isOn: $settings.backupNotificationsEnabled)
            }

            Section("Login item") {
                Toggle("Open at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { new in
                        do {
                            try settings.setLaunchAtLogin(new)
                        } catch {
                            launchError = error.localizedDescription
                            launchAtLogin = settings.isLaunchAtLoginEnabled()
                        }
                    }
                if let launchError {
                    Text(launchError).foregroundStyle(.red).font(.caption)
                }
            }
        }
        .formStyle(.grouped)
        .onAppear {
            launchAtLogin = settings.isLaunchAtLoginEnabled()
        }
    }
}
