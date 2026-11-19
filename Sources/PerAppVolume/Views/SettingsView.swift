import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: MixerModel
    @EnvironmentObject private var l10n: Localizer

    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    @State private var needsApproval = LaunchAtLogin.needsApproval
    @State private var launchError: String?

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
    }

    var body: some View {
        Form {
            Section(l10n.t(.general)) {
                Toggle(isOn: $launchAtLogin) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(l10n.t(.launchAtLogin))
                        Text(l10n.t(.launchAtLoginHelp)).font(.caption).foregroundStyle(.secondary)
                    }
                }
                .onChange(of: launchAtLogin) { _, newValue in setLaunchAtLogin(newValue) }

                if needsApproval {
                    Label(l10n.t(.launchNeedsApproval), systemImage: "exclamationmark.triangle")
                        .font(.caption).foregroundStyle(.orange)
                } else if !LaunchAtLogin.isInApplicationsFolder {
                    Label(l10n.t(.launchMoveToApplications), systemImage: "info.circle")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if let launchError {
                    Text(launchError).font(.caption).foregroundStyle(.red)
                }

                Picker(selection: $l10n.choice) {
                    ForEach(LanguageChoice.allCases) { Text(l10n.label(for: $0)).tag($0) }
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(l10n.t(.language))
                        Text(l10n.t(.languageHelp)).font(.caption).foregroundStyle(.secondary)
                    }
                }

                Button(l10n.t(.resetAll)) { model.resetAll() }
                    .disabled(model.settings.isEmpty)
            }

            Section(l10n.t(.permissions)) {
                Text(l10n.t(.permissionsHelp)).font(.callout).foregroundStyle(.secondary)
                Button(l10n.t(.openPrivacy)) {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AudioCapture") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }

            Section(l10n.t(.about)) {
                LabeledContent(l10n.t(.version), value: version)
                Text(l10n.t(.aboutText)).font(.callout).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 480)
        .fixedSize(horizontal: false, vertical: true)
        .onAppear(perform: refreshLaunchState)
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        guard enabled != LaunchAtLogin.isEnabled else { refreshLaunchState(); return }
        do {
            try LaunchAtLogin.set(enabled)
            launchError = nil
        } catch {
            launchError = error.localizedDescription
        }
        refreshLaunchState()
    }

    private func refreshLaunchState() {
        needsApproval = LaunchAtLogin.needsApproval
        let enabled = LaunchAtLogin.isEnabled || needsApproval
        if launchAtLogin != enabled { launchAtLogin = enabled }
    }
}
