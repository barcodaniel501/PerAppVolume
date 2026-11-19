import Foundation
import ServiceManagement

/// "Open at login" using the modern SMAppService API (macOS 13+).
enum LaunchAtLogin {
    static var status: SMAppService.Status { SMAppService.mainApp.status }
    static var isEnabled: Bool { status == .enabled }
    static var needsApproval: Bool { status == .requiresApproval }
    static var isInApplicationsFolder: Bool { Bundle.main.bundlePath.hasPrefix("/Applications/") }

    static func set(_ enabled: Bool) throws {
        if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
    }

    /// On the very first launch from /Applications, turn "open at login" on (it can be turned off in Settings).
    static func applyFirstRunDefault() {
        let key = "didApplyLaunchAtLoginDefault"
        guard !UserDefaults.standard.bool(forKey: key), isInApplicationsFolder else { return }
        UserDefaults.standard.set(true, forKey: key)
        try? set(true)
    }
}
