import AppKit

@MainActor
final class StatusBarController: NSObject {
    let statusItem: NSStatusItem
    private let settings: SettingsManager
    private let audio: AudioManager
    private let countdown: CountdownManager
    private let oauth: OAuthManager
    private let calendar: GoogleCalendarService
    private let eventScheduler: EventScheduler
    private let openSettings: () -> Void

    private var menu: NSMenu!
    private weak var connectMenuItem: NSMenuItem?
    private weak var disconnectMenuItem: NSMenuItem?

    init(
        settings: SettingsManager,
        audio: AudioManager,
        countdown: CountdownManager,
        oauth: OAuthManager,
        calendar: GoogleCalendarService,
        eventScheduler: EventScheduler,
        openSettings: @escaping () -> Void
    ) {
        self.settings = settings
        self.audio = audio
        self.countdown = countdown
        self.oauth = oauth
        self.calendar = calendar
        self.eventScheduler = eventScheduler
        self.openSettings = openSettings
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        configureButton()
        buildMenu()
    }

    private func configureButton() {
        if let button = statusItem.button {
            button.toolTip = "Just Before The Meeting"
            button.target = self
            button.action = #selector(statusBarClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }

    @objc private func statusBarClicked(_ sender: Any?) {
        if countdown.isActive {
            countdown.cancel(userInitiated: true, audio: audio)
            return
        }
        guard let button = statusItem.button else { return }
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height), in: button)
    }

    private func buildMenu() {
        menu = NSMenu()
        menu.delegate = self

        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettingsMenu), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())

        let connect = makeConnectMenuItem()
        let disconnect = makeDisconnectMenuItem()
        connectMenuItem = connect
        disconnectMenuItem = disconnect
        menu.addItem(connect)
        menu.addItem(disconnect)

        menu.addItem(NSMenuItem.separator())

        let testSound = NSMenuItem(title: "Test Sound (5s preview)", action: #selector(testSound), keyEquivalent: "")
        testSound.target = self
        menu.addItem(testSound)

        let testCountdown = NSMenuItem(title: "Test Countdown + Music", action: #selector(testCountdown), keyEquivalent: "")
        testCountdown.target = self
        menu.addItem(testCountdown)

        let syncItem = NSMenuItem(title: "Sync Calendar Now", action: #selector(syncNow), keyEquivalent: "")
        syncItem.target = self
        menu.addItem(syncItem)

        menu.addItem(NSMenuItem.separator())

        let aboutItem = NSMenuItem(title: "About", action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)

        let quitItem = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
    }

    @objc private func openSettingsMenu() {
        openSettings()
    }

    @objc private func connectCalendar() {
        Task {
            do {
                try await oauth.signIn()
                await calendar.refreshEvents()
                await MainActor.run { self.eventScheduler.start() }
            } catch {
                await MainActor.run {
                    NSAlert(error: error).runModal()
                }
            }
        }
    }

    @objc private func disconnectCalendar() {
        oauth.signOut()
        eventScheduler.stop()
        eventScheduler.start()
    }

    @objc private func testSound() {
        Task { @MainActor in
            audio.preview()
        }
    }

    @objc private func testCountdown() {
        countdown.beginManualTest(audio: audio)
    }

    private func makeConnectMenuItem() -> NSMenuItem {
        let connectTitle = oauth.isAuthorized ? "Reconnect Google Calendar" : "Connect Google Calendar"
        let connectItem = NSMenuItem(title: connectTitle, action: #selector(connectCalendar), keyEquivalent: "")
        connectItem.target = self
        return connectItem
    }

    private func makeDisconnectMenuItem() -> NSMenuItem {
        let disconnectItem = NSMenuItem(title: "Disconnect Google", action: #selector(disconnectCalendar), keyEquivalent: "")
        disconnectItem.target = self
        disconnectItem.isEnabled = oauth.isAuthorized
        return disconnectItem
    }

    @objc private func syncNow() {
        Task {
            await calendar.refreshEvents()
            await MainActor.run { self.eventScheduler.start() }
        }
    }

    @objc private func showAbout() {
        let alert = NSAlert()
        alert.messageText = "Just Before The Meeting"
        alert.informativeText = "Menu bar countdown and theme before your meetings.\n\nSet your Google OAuth Client ID in Info.plist (GoogleOAuthClientID)."
        alert.alertStyle = .informational
        alert.runModal()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

extension StatusBarController: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        guard menu === self.menu else { return }
        connectMenuItem?.title = oauth.isAuthorized ? "Reconnect Google Calendar" : "Connect Google Calendar"
        disconnectMenuItem?.isEnabled = oauth.isAuthorized
    }
}
