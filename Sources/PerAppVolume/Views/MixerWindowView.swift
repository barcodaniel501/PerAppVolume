import SwiftUI

/// The larger mixer window.
struct MixerWindowView: View {
    @EnvironmentObject private var model: MixerModel
    @EnvironmentObject private var l10n: Localizer

    var body: some View {
        VStack(spacing: 0) {
            SystemVolumeRow(large: true)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text(l10n.t(.apps).uppercased())
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 16)
                        .padding(.top, 10)
                    AppListView(large: true).padding(.vertical, 4)
                }
            }
            Divider()
            HStack {
                Button(l10n.t(.resetAll)) { model.resetAll() }
                    .disabled(model.settings.isEmpty)
                Spacer()
                Button(l10n.t(.settings)) { WindowManager.shared.showSettings() }
            }
            .padding(12)
        }
        .frame(minWidth: 420, idealWidth: 460, minHeight: 320, idealHeight: 480)
    }
}
