import AppKit
import Combine
import Foundation

@MainActor
final class CountdownManager: ObservableObject {
    private let settings: SettingsManager
    private let calendar: GoogleCalendarService
    private weak var statusItem: NSStatusItem?

    private var tickTimer: Timer?
    private var pulseTimer: Timer?
    private var idleRefreshTimer: Timer?
    private var remainingSeconds: Int = 0
    private var pulseOn = false
    private var cancellables = Set<AnyCancellable>()

    private(set) var isActive = false
    private var currentTitle: String = ""

    init(settings: SettingsManager, calendar: GoogleCalendarService) {
        self.settings = settings
        self.calendar = calendar

        calendar.$events
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshIdleTitleIfNeeded()
            }
            .store(in: &cancellables)

        settings.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshIdleTitleIfNeeded()
            }
            .store(in: &cancellables)
    }

    func attachStatusItem(_ item: NSStatusItem) {
        statusItem = item
        startIdleRefreshTimerIfNeeded()
        refreshIdleTitle()
    }

    /// Idle state: next meeting + time until start, or "JBTM" when nothing applies.
    func refreshIdleTitle() {
        guard !isActive else { return }
        guard let button = statusItem?.button else { return }

        guard let next = settings.nextUpcomingFilteredEvent(from: calendar.events) else {
            applyFallbackIdleTitle(to: button)
            return
        }

        let now = Date()
        let untilStart = compactTimeUntil(next.start, from: now)
        let shown = truncateMeetingTitle(next.title, maxUTF8: 26)
        let line = "\(shown) · \(untilStart)"

        button.attributedTitle = NSAttributedString(
            string: line,
            attributes: [
                .font: NSFont.systemFont(ofSize: 12, weight: .semibold),
                .foregroundColor: NSColor.labelColor
            ]
        )

        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .short
        button.toolTip = "\(next.title)\nStarts \(df.string(from: next.start))"
    }

    private func applyFallbackIdleTitle(to button: NSStatusBarButton) {
        button.attributedTitle = NSAttributedString(
            string: "JBTM",
            attributes: [.font: NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .semibold)]
        )
        button.toolTip = "Just Before The Meeting"
    }

    private func refreshIdleTitleIfNeeded() {
        guard !isActive else { return }
        refreshIdleTitle()
    }

    private func startIdleRefreshTimerIfNeeded() {
        idleRefreshTimer?.invalidate()
        let t = Timer(timeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshIdleTitleIfNeeded()
            }
        }
        idleRefreshTimer = t
        RunLoop.main.add(t, forMode: .common)
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
        refreshIdleTitle()
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
                    self?.refreshIdleTitle()
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
        let timeText = String(format: "⏰ %d:%02d", m, s)

        let nameColor: NSColor
        if pulseOn {
            nameColor = NSColor.systemRed
        } else {
            nameColor = NSColor.systemOrange
        }

        let shownName = truncateMeetingTitle(currentTitle, maxUTF8: 22)
        let full = NSMutableAttributedString()
        full.append(NSAttributedString(string: shownName, attributes: [
            .font: NSFont.systemFont(ofSize: 12, weight: .heavy),
            .foregroundColor: nameColor
        ]))
        full.append(NSAttributedString(string: "  ", attributes: [
            .font: NSFont.systemFont(ofSize: 12, weight: .regular),
            .foregroundColor: NSColor.labelColor
        ]))
        full.append(NSAttributedString(string: timeText, attributes: [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .semibold),
            .foregroundColor: NSColor.labelColor
        ]))
        button.attributedTitle = full
        button.toolTip = "\(currentTitle)\n\(timeText)"
    }

    private func compactTimeUntil(_ date: Date, from now: Date) -> String {
        let sec = max(0, date.timeIntervalSince(now))
        if sec < 60 { return "<1m" }
        let minutes = Int(ceil(sec / 60))
        if minutes < 60 { return "\(minutes)m" }
        let h = minutes / 60
        let rem = minutes % 60
        return rem > 0 ? "\(h)h \(rem)m" : "\(h)h"
    }

    private func truncateMeetingTitle(_ s: String, maxUTF8: Int) -> String {
        if s.utf8.count <= maxUTF8 { return s }
        var result = ""
        for ch in s {
            let add = String(ch).utf8.count
            if result.utf8.count + add > maxUTF8 - 1 { break }
            result.append(ch)
        }
        return result + "…"
    }
}
