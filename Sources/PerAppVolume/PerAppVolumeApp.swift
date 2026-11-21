import AppKit
import SwiftUI

struct PerAppVolumeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        // The menu bar icon and its menu are created by StatusItemController (a real NSMenu,
        // so it looks and behaves like the system menus). SwiftUI needs at least one scene.
        Settings { EmptyView() }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        MixerModel.shared.start()
        SystemVolume.shared.start()
        StatusItemController.shared.install()
        LaunchAtLogin.applyFirstRunDefault()
    }

    func applicationWillTerminate(_ notification: Notification) {
        MixerModel.shared.stopAll()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}
