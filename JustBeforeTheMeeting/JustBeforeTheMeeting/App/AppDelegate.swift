import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settings = SettingsManager()
    private lazy var audioManager = AudioManager(settings: settings)
    private lazy var countdownManager = CountdownManager(settings: settings)
    private lazy var oauthManager = OAuthManager(settings: settings)
    private lazy var calendarService = GoogleCalendarService(settings: settings, oauth: oauthManager)
    private lazy var eventScheduler = EventScheduler(
        settings: settings,
        calendar: calendarService,
        audio: audioManager,
        countdown: countdownManager
    )

    private var statusBar: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let status = StatusBarController(
            settings: settings,
            audio: audioManager,
            countdown: countdownManager,
            oauth: oauthManager,
            calendar: calendarService,
            eventScheduler: eventScheduler,
            openSettings: { [weak self] in self?.openSettings() }
        )
        statusBar = status

        countdownManager.attachStatusItem(status.statusItem)

        eventScheduler.start()

        UNNotificationHelper.requestAuthorizationIfNeeded()
    }

    func applicationWillTerminate(_ notification: Notification) {
        eventScheduler.stop()
        audioManager.stop()
        countdownManager.cancel()
    }

    private func openSettings() {
        SettingsWindowController.present(
            settings: settings,
            audio: audioManager,
            oauth: oauthManager,
            calendar: calendarService,
            eventScheduler: eventScheduler
        )
    }
}
