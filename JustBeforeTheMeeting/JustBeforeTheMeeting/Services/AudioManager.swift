import AppKit
import AVFoundation
import Foundation
import UniformTypeIdentifiers

@MainActor
final class AudioManager: NSObject, ObservableObject {
    private let settings: SettingsManager
    private var player: AVAudioPlayer?
    private var fadeTimer: Timer?
    private var previewStopTimer: Timer?

    init(settings: SettingsManager) {
        self.settings = settings
        super.init()
    }

    /// Resolves URL: custom path from settings, then bundle `default_theme`.
    func resolvedSoundURL() -> URL? {
        if let path = settings.customSoundPath, FileManager.default.fileExists(atPath: path) {
            return URL(fileURLWithPath: path)
        }
        return Bundle.main.url(forResource: "default_theme", withExtension: "mp3")
            ?? Bundle.main.url(forResource: "default_theme", withExtension: "m4a")
    }

    func pickCustomSoundFile() -> URL? {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.audio, .mp3, .mpeg4Audio]
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        settings.customSoundPath = url.path
        return url
    }

    /// Preview only: fade in briefly then fade out (does not use full countdown).
    func preview() {
        cancelFade()
        previewStopTimer?.invalidate()
        guard let url = resolvedSoundURL() else { return }
        do {
            let p = try AVAudioPlayer(contentsOf: url)
            p.volume = 0
            p.prepareToPlay()
            player = p
            p.play()
            fadeIn(duration: 1.0, targetVolume: Float(settings.volume))
            previewStopTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { [weak self] _ in
                Task { @MainActor in
                    self?.fadeOut(duration: 0.8) {
                        self?.player?.stop()
                        self?.player = nil
                    }
                }
            }
        } catch {
            NSSound.beep()
        }
    }

    func playWithFadeIn(duration: TimeInterval = 1.0) {
        cancelFade()
        previewStopTimer?.invalidate()
        guard let url = resolvedSoundURL() else {
            NSSound.beep()
            return
        }
        do {
            let p = try AVAudioPlayer(contentsOf: url)
            p.numberOfLoops = 0
            p.volume = 0
            p.prepareToPlay()
            player = p
            p.play()
            fadeIn(duration: duration, targetVolume: Float(settings.volume))
        } catch {
            NSSound.beep()
        }
    }

    func setVolume(_ value: Float) {
        player?.volume = value
    }

    func stop() {
        cancelFade()
        previewStopTimer?.invalidate()
        player?.stop()
        player = nil
    }

    func fadeOut(duration: TimeInterval, completion: @escaping () -> Void) {
        cancelFade()
        guard let p = player else {
            completion()
            return
        }
        let steps = max(1, Int(duration / 0.05))
        let start = p.volume
        var step = 0
        fadeTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] t in
            Task { @MainActor in
                guard let self, let player = self.player else {
                    t.invalidate()
                    completion()
                    return
                }
                step += 1
                let ratio = Float(step) / Float(steps)
                player.volume = start * (1 - ratio)
                if step >= steps {
                    t.invalidate()
                    self.fadeTimer = nil
                    completion()
                }
            }
        }
    }

    private func fadeIn(duration: TimeInterval, targetVolume: Float) {
        cancelFade()
        guard let p = player else { return }
        p.volume = 0
        let steps = max(1, Int(duration / 0.05))
        var step = 0
        fadeTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] t in
            Task { @MainActor in
                guard let self, let player = self.player else {
                    t.invalidate()
                    return
                }
                step += 1
                let progress = Float(step) / Float(steps)
                player.volume = targetVolume * progress
                if step >= steps {
                    t.invalidate()
                    self.fadeTimer = nil
                    player.volume = targetVolume
                }
            }
        }
    }

    private func cancelFade() {
        fadeTimer?.invalidate()
        fadeTimer = nil
    }

}
