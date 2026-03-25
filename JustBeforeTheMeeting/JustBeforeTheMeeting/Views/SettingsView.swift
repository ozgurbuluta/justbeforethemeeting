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
                .tabItem { Label("Calendar", systemImage: "calendar") }

            EventRulesSettingsView()
                .tabItem { Label("Events", systemImage: "line.3.horizontal.decrease.circle") }

            SoundSettingsView()
                .tabItem { Label("Sound", systemImage: "speaker.wave.2") }

            GeneralSettingsView()
                .tabItem { Label("General", systemImage: "gearshape") }
        }
        .frame(minWidth: 500, minHeight: 380)
        .padding()
    }
}
