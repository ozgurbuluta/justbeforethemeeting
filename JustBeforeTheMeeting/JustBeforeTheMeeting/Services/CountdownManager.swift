import AppKit
import Combine
import Foundation

@MainActor
final class CountdownManager: ObservableObject {
    private let settings: SettingsManager
    private weak var statusItem: NSStatusItem?

    private var tickTimer: Timer?
    private var pulseTimer: Timer?
    private var remainingSeconds: Int = 0
    private var pulseOn = false

    private(set) var isActive = false
    private var currentTitle: String = ""

    init(settings: SettingsManager) {
        self.settings = settings
    }

    func attachStatusItem(_ item: NSStatusItem) {
        statusItem = item
        setNormalTitle()
    }

    func setNormalTitle() {
        statusItem?.button?.attributedTitle = NSAttributedString(
            string: "JBTM",
            attributes: [.font: NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .semibold)]
        )
    }

    /// Starts countdown + audio for a meeting (or test).
    func startCountdown(seconds: Int, meetingTitle: String, audio: AudioManager, notify: Bool) {
        cancel(userInitiated: false)
        isActive = true
        remainingSeconds = max(1, seconds)
        currentTitle = meetingTitle

        audio.playWithFadeIn(duration: 1.0)

        if notify, settings.backupNotificationsEnabled {
            UNNotificationHelper.notifyCountdownStarted(title: meetingTitle, seconds: remainingSeconds)
        }

        updateAttributedTitle()
        startPulse()
        let tick = Timer(timeInterval: 1.0, repeats: true) { [weak self] t in
            Task { @MainActor in
                self?.tick(audio: audio, timer: t)
            }
        }
        tickTimer = tick
        RunLoop.main.add(tick, forMode: .common)
    }

    func beginManualTest(audio: AudioManager) {
        let s = settings.countdownDurationSeconds
        startCountdown(seconds: s, meetingTitle: "Test", audio: audio, notify: false)
    }

    func cancel(userInitiated: Bool = true, audio: AudioManager? = nil) {
        tickTimer?.invalidate()
        tickTimer = nil
        pulseTimer?.invalidate()
        pulseTimer = nil
        isActive = false
        remainingSeconds = 0
        if userInitiated {
            audio?.stop()
        }
        setNormalTitle()
    }

    private func tick(audio: AudioManager, timer: Timer) {
        remainingSeconds -= 1
        if remainingSeconds <= 0 {
            timer.invalidate()
            tickTimer = nil
            pulseTimer?.invalidate()
            pulseTimer = nil
            isActive = false
            audio.fadeOut(duration: 0.6) { [weak self] in
                Task { @MainActor in
                    audio.stop()
                    self?.setNormalTitle()
                }
            }
            return
        }
        updateAttributedTitle()
    }

    private func startPulse() {
        pulseTimer?.invalidate()
        let pulse = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.pulseOn.toggle()
                self?.updateAttributedTitle()
            }
        }
        pulseTimer = pulse
        RunLoop.main.add(pulse, forMode: .common)
    }

    private func updateAttributedTitle() {
        guard let button = statusItem?.button else { return }
        let m = remainingSeconds / 60
        let s = remainingSeconds % 60
        let text = String(format: "⏰ %d:%02d", m, s)

        let color: NSColor
        if pulseOn {
            color = NSColor.systemRed
        } else {
            color = NSColor.systemOrange
        }

        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .heavy),
            .foregroundColor: color
        ]
        button.attributedTitle = NSAttributedString(string: text, attributes: attrs)
        button.toolTip = currentTitle
    }
}
