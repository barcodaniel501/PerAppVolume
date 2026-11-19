import AppKit
import Combine
import SwiftUI

/// Opens the mixer and settings windows (PerAppVolume lives in the menu bar, without a Dock icon).
@MainActor
final class WindowManager {
    static let shared = WindowManager()

    private var mixerWindow: NSWindow?
    private var settingsWindow: NSWindow?
    private var cancellable: AnyCancellable?

    private init() {
        // Keep window titles in the selected language.
        cancellable = Localizer.shared.$choice.sink { [weak self] _ in
            DispatchQueue.main.async { self?.updateTitles() }
        }
    }

    func showMixer() {
        if mixerWindow == nil {
            mixerWindow = makeWindow(MixerWindowView(), resizable: true)
            mixerWindow?.setContentSize(NSSize(width: 460, height: 480))
            mixerWindow?.setFrameAutosaveName("MixerWindow")
        }
        present(mixerWindow)
    }

    func showSettings() {
        if settingsWindow == nil {
            settingsWindow = makeWindow(SettingsView(), resizable: false)
        }
        present(settingsWindow)
    }

    private func makeWindow<V: View>(_ view: V, resizable: Bool) -> NSWindow {
        var style: NSWindow.StyleMask = [.titled, .closable, .miniaturizable]
        if resizable { style.insert(.resizable) }
        let window = NSWindow(contentRect: .zero, styleMask: style, backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentViewController = NSHostingController(
            rootView: view
                .environmentObject(MixerModel.shared)
                .environmentObject(SystemVolume.shared)
                .environmentObject(Localizer.shared)
        )
        window.center()
        return window
    }

    private func present(_ window: NSWindow?) {
        guard let window else { return }
        updateTitles()
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    private func updateTitles() {
        mixerWindow?.title = "PerAppVolume"
        settingsWindow?.title = "PerAppVolume – \(Localizer.shared.t(.settingsTitle))"
    }
}
