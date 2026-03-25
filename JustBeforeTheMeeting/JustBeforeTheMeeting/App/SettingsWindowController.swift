import AppKit
import SwiftUI

final class SettingsWindowController: NSWindowController {
    private static var instance: SettingsWindowController?

    static func present(
        settings: SettingsManager,
        audio: AudioManager,
        oauth: OAuthManager,
        calendar: GoogleCalendarService,
        eventScheduler: EventScheduler
    ) {
        if instance == nil {
            let root = SettingsView()
                .environmentObject(settings)
                .environmentObject(audio)
                .environmentObject(oauth)
                .environmentObject(calendar)
                .environmentObject(eventScheduler)

            let hosting = NSHostingController(rootView: root)
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 520, height: 420),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.title = "Just Before The Meeting — Settings"
            window.contentViewController = hosting
            window.center()
            window.setFrameAutosaveName("SettingsWindow")
            instance = SettingsWindowController(window: window)
        }
        instance?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
