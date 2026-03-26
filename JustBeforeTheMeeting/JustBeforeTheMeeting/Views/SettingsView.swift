import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settings: SettingsManager
    @EnvironmentObject private var audio: AudioManager
    @EnvironmentObject private var oauth: OAuthManager
    @EnvironmentObject private var calendar: GoogleCalendarService
    @EnvironmentObject private var eventScheduler: EventScheduler

    var body: some View {
        TabView {
            CalendarSettingsView()
                .tabItem { Label(L10n.s("tab.calendar"), systemImage: "calendar") }

            EventRulesSettingsView()
                .tabItem { Label(L10n.s("tab.events"), systemImage: "line.3.horizontal.decrease.circle") }

            SoundSettingsView()
                .tabItem { Label(L10n.s("tab.sound"), systemImage: "speaker.wave.2") }

            GeneralSettingsView()
                .tabItem { Label(L10n.s("tab.general"), systemImage: "gearshape") }
        }
        .frame(minWidth: 500, minHeight: 380)
        .padding()
    }
}
