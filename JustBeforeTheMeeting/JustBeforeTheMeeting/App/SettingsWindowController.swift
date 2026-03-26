import AppKit
import SwiftUI

final class SettingsWindowController: NSWindowController {
    private static var instance: SettingsWindowController?
    private var languageObserver: NSObjectProtocol?

    override init(window: NSWindow?) {
        super.init(window: window)
        languageObserver = NotificationCenter.default.addObserver(
            forName: .jbtmUILanguageDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.window?.title = L10n.s("settings.window_title")
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        if let languageObserver {
            NotificationCenter.default.removeObserver(languageObserver)
        }
    }

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
            window.title = L10n.s("settings.window_title")
            window.contentViewController = hosting
            window.center()
            window.setFrameAutosaveName("SettingsWindow")
            instance = SettingsWindowController(window: window)
        }
        instance?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
