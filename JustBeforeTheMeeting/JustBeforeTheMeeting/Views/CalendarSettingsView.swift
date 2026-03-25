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
                    Text("Add **GoogleOAuthClientID** to Info.plist. Create an OAuth **Desktop** client in Google Cloud Console and add redirect URI **jbtm://oauth**.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                LabeledContent("Status") {
                    Text(oauth.isAuthorized ? "Connected" : "Not connected")
                        .foregroundStyle(oauth.isAuthorized ? .green : .secondary)
                }

                if let sync = calendar.lastSync {
                    LabeledContent("Last sync") {
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
                Button("Sign in with Google…") {
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

                Button("Disconnect", role: .destructive) {
                    oauth.signOut()
                    eventScheduler.stop()
                    eventScheduler.start()
                }
                .disabled(!oauth.isAuthorized)

                Button("Sync now") {
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
