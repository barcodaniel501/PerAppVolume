import AppKit
import SwiftUI

struct PerAppVolumeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var model = MixerModel.shared
    @StateObject private var l10n = Localizer.shared
    @StateObject private var system = SystemVolume.shared

    var body: some Scene {
        MenuBarExtra {
            MenuContentView()
                .environmentObject(model)
                .environmentObject(system)
                .environmentObject(l10n)
        } label: {
            Image(systemName: "slider.vertical.3")
        }
        .menuBarExtraStyle(.window)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        MixerModel.shared.start()
        SystemVolume.shared.start()
        LaunchAtLogin.applyFirstRunDefault()
    }

    func applicationWillTerminate(_ notification: Notification) {
        MixerModel.shared.stopAll()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}
