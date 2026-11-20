import Foundation
import ServiceManagement

/// "Open at login" using the modern SMAppService API (macOS 13+).
enum LaunchAtLogin {
    /// When true (screenshots), reports "enabled" without touching the real login item.
    @MainActor static var demoMode = false

    static var status: SMAppService.Status { SMAppService.mainApp.status }
    @MainActor static var isEnabled: Bool { demoMode || status == .enabled }
    @MainActor static var needsApproval: Bool { !demoMode && status == .requiresApproval }
    @MainActor static var isInApplicationsFolder: Bool { demoMode || Bundle.main.bundlePath.hasPrefix("/Applications/") }

    static func set(_ enabled: Bool) throws {
        if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
    }

    /// On the very first launch from /Applications, turn "open at login" on (it can be turned off in Settings).
    @MainActor static func applyFirstRunDefault() {
        let key = "didApplyLaunchAtLoginDefault"
        guard !UserDefaults.standard.bool(forKey: key), isInApplicationsFolder else { return }
        UserDefaults.standard.set(true, forKey: key)
        try? set(true)
    }
}
