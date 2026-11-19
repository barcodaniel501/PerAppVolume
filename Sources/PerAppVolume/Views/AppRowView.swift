import SwiftUI

/// One app: icon, name, "playing" dot, mute button, 0–200% slider and percentage.
struct AppRowView: View {
    @EnvironmentObject private var model: MixerModel
    @EnvironmentObject private var l10n: Localizer
    let app: AudioApp
    var large = false

    private var setting: AppSetting { model.setting(for: app.id) }
    private var percent: Int { Int((setting.volume * 100).rounded()) }

    private var volume: Binding<Double> {
        Binding(
            get: { model.setting(for: app.id).volume },
            // Snap to 100% near the middle so it's easy to go back to the original volume.
            set: { model.setVolume(abs($0 - 1) < 0.04 ? 1 : $0, for: app.id) }
        )
    }

    var body: some View {
        HStack(spacing: large ? 12 : 10) {
            Image(nsImage: model.icon(for: app))
                .resizable()
                .frame(width: large ? 36 : 28, height: large ? 36 : 28)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(app.name)
                        .font(large ? .body.weight(.medium) : .callout.weight(.medium))
                        .lineLimit(1)
                    if app.isPlaying {
                        Circle().fill(.green).frame(width: 6, height: 6).help(l10n.t(.playing))
                    }
                    Spacer(minLength: 4)
                    Text(setting.muted ? "—" : "\(percent)%")
                        .font(.callout.monospacedDigit())
                        .foregroundStyle(percent > 100 && !setting.muted ? Color.orange : Color.secondary)
                        .frame(minWidth: 44, alignment: .trailing)
                }
                HStack(spacing: 6) {
                    Button {
                        model.toggleMute(for: app.id)
                    } label: {
                        Image(systemName: setting.muted ? "speaker.slash.fill" : volumeSymbol)
                            .frame(width: 18)
                            .foregroundStyle(setting.muted ? Color.red : Color.primary)
                    }
                    .buttonStyle(.borderless)
                    .help(setting.muted ? l10n.t(.unmute) : l10n.t(.mute))

                    Slider(value: volume, in: 0...2)
                        .controlSize(large ? .regular : .small)
                        .opacity(setting.muted ? 0.4 : 1)
                }
                if let error = model.errors[app.id] {
                    Text("\(l10n.t(.tapError)) \(error)")
                        .font(.caption)
                        .foregroundStyle(.red)
                        .lineLimit(2)
                }
            }
        }
        .padding(.vertical, large ? 6 : 4)
        .contextMenu {
            Button(l10n.t(.resetApp)) { model.reset(app.id) }
            Button(setting.muted ? l10n.t(.unmute) : l10n.t(.mute)) { model.toggleMute(for: app.id) }
        }
    }

    private var volumeSymbol: String {
        switch setting.volume {
        case ..<0.01: return "speaker.fill"
        case ..<0.5: return "speaker.wave.1.fill"
        case ..<1.01: return "speaker.wave.2.fill"
        default: return "speaker.wave.3.fill"
        }
    }
}

/// List of apps, or a friendly empty state.
struct AppListView: View {
    @EnvironmentObject private var model: MixerModel
    @EnvironmentObject private var l10n: Localizer
    var large = false

    var body: some View {
        if model.apps.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "speaker.zzz")
                    .font(.system(size: large ? 34 : 24))
                    .foregroundStyle(.secondary)
                Text(l10n.t(.noApps)).font(.callout.weight(.medium))
                Text(l10n.t(.noAppsHint))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, large ? 40 : 20)
            .padding(.horizontal, 16)
        } else {
            VStack(spacing: 0) {
                ForEach(model.apps) { app in
                    AppRowView(app: app, large: large)
                        .padding(.horizontal, large ? 16 : 12)
                    if app.id != model.apps.last?.id { Divider().padding(.leading, large ? 64 : 50) }
                }
            }
        }
    }
}
