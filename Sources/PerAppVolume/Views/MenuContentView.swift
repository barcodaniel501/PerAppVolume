import SwiftUI

/// Content of the menu bar panel.
struct MenuContentView: View {
    @EnvironmentObject private var model: MixerModel
    @EnvironmentObject private var l10n: Localizer

    private let maxListHeight: CGFloat = 380

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("PerAppVolume").font(.headline)
                Spacer()
                Text(l10n.t(.subtitle)).font(.caption).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            Divider()

            SystemVolumeRow()
                .padding(.horizontal, 12)
                .padding(.vertical, 4)

            Divider()

            Text(l10n.t(.apps).uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.top, 8)

            if model.apps.count > 6 {
                ScrollView { AppListView().padding(.vertical, 4) }
                    .frame(height: maxListHeight)
            } else {
                AppListView().padding(.vertical, 4)
            }

            Divider()

            HStack(spacing: 14) {
                Button(l10n.t(.openWindow)) { WindowManager.shared.showMixer() }
                Button(l10n.t(.settings)) { WindowManager.shared.showSettings() }
                Spacer()
                Button(l10n.t(.quit)) { NSApp.terminate(nil) }
                    .keyboardShortcut("q")
            }
            .buttonStyle(.borderless)
            .font(.callout)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
        }
        .frame(width: 340)
    }
}
