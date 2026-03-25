import SwiftUI

struct SoundSettingsView: View {
    @EnvironmentObject private var settings: SettingsManager
    @EnvironmentObject private var audio: AudioManager

    var body: some View {
        Form {
            Section("Audio file") {
                if let path = settings.customSoundPath {
                    Text(path)
                        .font(.caption)
                        .lineLimit(2)
                        .textSelection(.enabled)
                } else {
                    Text("Using **default_theme** from the app bundle if present (mp3/m4a).")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                Button("Choose sound file…") {
                    _ = audio.pickCustomSoundFile()
                }

                Button("Test preview (5s)") {
                    audio.preview()
                }
            }

            Section("Volume") {
                Slider(value: $settings.volume, in: 0 ... 1) {
                    Text("Volume")
                }
                Text("\(Int(settings.volume * 100))%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}
