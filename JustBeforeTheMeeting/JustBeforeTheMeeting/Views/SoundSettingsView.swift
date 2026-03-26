import SwiftUI

struct SoundSettingsView: View {
    @EnvironmentObject private var settings: SettingsManager
    @EnvironmentObject private var audio: AudioManager

    var body: some View {
        Form {
            Section(L10n.s("sound.section_file")) {
                if let path = settings.customSoundPath {
                    Text(path)
                        .font(.caption)
                        .lineLimit(2)
                        .textSelection(.enabled)
                } else {
                    L10n.markdown("sound.default_theme_hint")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                Button(L10n.s("sound.choose_file")) {
                    _ = audio.pickCustomSoundFile()
                }

                Button(L10n.s("sound.test_preview")) {
                    audio.preview()
                }
            }

            Section(L10n.s("sound.section_volume")) {
                Slider(value: $settings.volume, in: 0 ... 1) {
                    Text(L10n.s("sound.volume_label"))
                }
                Text(L10n.s("sound.volume_percent", Int64(Int(settings.volume * 100))))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}
