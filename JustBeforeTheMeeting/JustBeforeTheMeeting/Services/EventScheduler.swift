import Combine
import Foundation

@MainActor
final class EventScheduler: ObservableObject {
    private let settings: SettingsManager
    private let calendar: GoogleCalendarService
    private let audio: AudioManager
    private let countdown: CountdownManager

    private var cancellables = Set<AnyCancellable>()
    private var workItems: [String: DispatchWorkItem] = [:]
    /// Prevents duplicate triggers for the same occurrence across refreshes.
    private var firedOccurrenceKeys = Set<String>()

    init(
        settings: SettingsManager,
        calendar: GoogleCalendarService,
        audio: AudioManager,
        countdown: CountdownManager
    ) {
        self.settings = settings
        self.calendar = calendar
        self.audio = audio
        self.countdown = countdown

        calendar.$events
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.reschedule()
            }
            .store(in: &cancellables)

        settings.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.reschedule()
            }
            .store(in: &cancellables)
    }

    func start() {
        calendar.startPollingIfNeeded()
        Task {
            await calendar.refreshEvents()
            await MainActor.run {
                self.reschedule()
            }
        }
    }

    func stop() {
        cancelAllWorkItems()
        calendar.stopPolling()
    }

    private func cancelAllWorkItems() {
        workItems.values.forEach { $0.cancel() }
        workItems.removeAll()
    }

    private func occurrenceKey(_ event: CalendarEvent) -> String {
        "\(event.id)|\(event.start.timeIntervalSince1970)"
    }

    private func reschedule() {
        cancelAllWorkItems()

        let now = Date()
        firedOccurrenceKeys = Set(
            firedOccurrenceKeys.filter { key in
                let parts = key.split(separator: "|")
                guard parts.count == 2, let ts = TimeInterval(parts[1]) else { return false }
                return Date(timeIntervalSince1970: ts) > now
            }
        )

        let advance = max(1, settings.advanceWarningSeconds)

        for event in calendar.events {
            guard settings.passesFilter(event) else { continue }
            let start = event.start
            let until = start.timeIntervalSince(now)
            if until <= 0 { continue }

            let delay = max(0, until - Double(advance))
            guard delay >= 0 else { continue }

            let occKey = occurrenceKey(event)
            if firedOccurrenceKeys.contains(occKey) { continue }

            let work = DispatchWorkItem { [weak self] in
                guard let self else { return }
                Task { @MainActor in
                    guard !self.firedOccurrenceKeys.contains(occKey) else { return }
                    let secondsUntilStart = Int(ceil(event.start.timeIntervalSince(Date())))
                    guard secondsUntilStart > 0 else { return }
                    let desired = max(1, self.settings.countdownDurationSeconds)
                    let countdownSeconds = min(desired, secondsUntilStart)
                    guard countdownSeconds > 0 else { return }
                    self.firedOccurrenceKeys.insert(occKey)
                    self.countdown.startCountdown(
                        seconds: countdownSeconds,
                        meetingTitle: event.title,
                        audio: self.audio,
                        notify: self.settings.backupNotificationsEnabled
                    )
                }
            }

            workItems[occKey] = work
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
        }
    }
}
