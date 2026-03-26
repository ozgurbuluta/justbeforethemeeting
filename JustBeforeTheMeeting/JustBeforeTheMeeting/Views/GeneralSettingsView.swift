import SwiftUI

struct GeneralSettingsView: View {
    @EnvironmentObject private var settings: SettingsManager
    @State private var launchAtLogin = false
    @State private var launchError: String?

    var body: some View {
        Form {
            Section(L10n.s("general.ui_language")) {
                Picker("", selection: Binding(
                    get: { settings.uiLanguageCode },
                    set: { settings.uiLanguageCode = $0 }
                )) {
                    Text("English").tag("en")
                    Text("Türkçe").tag("tr")
                }
                .labelsHidden()
                .pickerStyle(.segmented)
            }

            Section(L10n.s("section.countdown")) {
                Stepper(value: $settings.countdownDurationSeconds, in: 5 ... 300, step: 5) {
                    L10n.markdownFormat("general.countdown_length", Int64(settings.countdownDurationSeconds))
                }
                Stepper(value: $settings.advanceWarningSeconds, in: 5 ... 300, step: 5) {
                    L10n.markdownFormat("general.advance_warning", Int64(settings.advanceWarningSeconds))
                }
                L10n.markdown("general.countdown_hint")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section(L10n.s("section.calendar_refresh")) {
                Picker(L10n.s("general.poll_interval"), selection: $settings.calendarPollIntervalSeconds) {
                    Text(L10n.s("general.poll_1m")).tag(60.0)
                    Text(L10n.s("general.poll_5m")).tag(300.0)
                    Text(L10n.s("general.poll_15m")).tag(900.0)
                }
            }

            Section(L10n.s("section.notifications")) {
                Toggle(L10n.s("general.backup_notification"), isOn: $settings.backupNotificationsEnabled)
            }

            Section(L10n.s("section.login_item")) {
                Toggle(L10n.s("general.open_at_login"), isOn: $launchAtLogin)
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
