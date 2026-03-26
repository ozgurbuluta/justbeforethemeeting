import AppKit
import SwiftUI

struct CalendarSettingsView: View {
    @EnvironmentObject private var oauth: OAuthManager
    @EnvironmentObject private var calendar: GoogleCalendarService
    @EnvironmentObject private var eventScheduler: EventScheduler

    var body: some View {
        Form {
            Section {
                if oauth.clientID.isEmpty {
                    L10n.markdown("calendar.oauth_hint")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                LabeledContent(L10n.s("calendar.status")) {
                    Text(oauth.isAuthorized ? L10n.s("calendar.connected") : L10n.s("calendar.not_connected"))
                        .foregroundStyle(oauth.isAuthorized ? .green : .secondary)
                }

                if let sync = calendar.lastSync {
                    LabeledContent(L10n.s("calendar.last_sync")) {
                        Text(sync.formatted(date: .abbreviated, time: .shortened))
                    }
                }

                if let err = calendar.lastError {
                    Text(err)
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }

            Section {
                Button(L10n.s("calendar.sign_in")) {
                    Task {
                        do {
                            try await oauth.signIn()
                            await calendar.refreshEvents()
                            await MainActor.run { eventScheduler.start() }
                        } catch {
                            await MainActor.run {
                                NSAlert(error: error).runModal()
                            }
                        }
                    }
                }
                .disabled(oauth.clientID.isEmpty)

                Button(L10n.s("calendar.disconnect"), role: .destructive) {
                    oauth.signOut()
                    eventScheduler.stop()
                    eventScheduler.start()
                }
                .disabled(!oauth.isAuthorized)

                Button(L10n.s("calendar.sync_now")) {
                    Task {
                        await calendar.refreshEvents()
                        await MainActor.run { eventScheduler.start() }
                    }
                }
                .disabled(!oauth.isAuthorized)
            }
        }
        .formStyle(.grouped)
    }
}
