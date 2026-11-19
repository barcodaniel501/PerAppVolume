import SwiftUI

/// Main (system) volume of the current output device.
struct SystemVolumeRow: View {
    @EnvironmentObject private var system: SystemVolume
    @EnvironmentObject private var l10n: Localizer
    var large = false

    private var percent: Int { Int((system.volume * 100).rounded()) }

    private var volume: Binding<Double> {
        Binding(get: { system.volume }, set: { system.setVolume($0) })
    }

    var body: some View {
        HStack(spacing: large ? 12 : 10) {
            Image(systemName: "hifispeaker.2.fill")
                .font(.system(size: large ? 18 : 14))
                .foregroundStyle(.white)
                .frame(width: large ? 36 : 28, height: large ? 36 : 28)
                .background(RoundedRectangle(cornerRadius: large ? 8 : 6).fill(Color.accentColor))

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(l10n.t(.systemVolume))
                        .font(large ? .body.weight(.semibold) : .callout.weight(.semibold))
                    if !system.deviceName.isEmpty {
                        Text(system.deviceName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 4)
                    Text(system.muted ? "—" : "\(percent)%")
                        .font(.callout.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(minWidth: 44, alignment: .trailing)
                }
                HStack(spacing: 6) {
                    Button {
                        system.toggleMute()
                    } label: {
                        Image(systemName: system.muted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                            .frame(width: 18)
                            .foregroundStyle(system.muted ? Color.red : Color.primary)
                    }
                    .buttonStyle(.borderless)
                    .disabled(!system.canMute)
                    .help(system.muted ? l10n.t(.unmute) : l10n.t(.mute))

                    Slider(value: volume, in: 0...1)
                        .controlSize(large ? .regular : .small)
                        .disabled(!system.canSetVolume)
                        .opacity(system.muted ? 0.4 : 1)
                }
                if !system.canSetVolume {
                    Text(l10n.t(.systemVolumeUnavailable))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, large ? 6 : 4)
    }
}
