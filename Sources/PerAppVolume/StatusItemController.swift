import AppKit
import Combine
import SwiftUI

/// The menu bar icon and its panel.
///
/// The panel is a real system menu (`NSMenu`) whose only item hosts the SwiftUI content. Being a
/// menu, macOS draws it exactly like Bluetooth or Wi-Fi: rounded corners and glass material, the
/// menu bar stays visible while it's open (even with "automatically hide the menu bar"), and it
/// closes with a click outside, Esc or another click on the icon.
@MainActor
final class StatusItemController: NSObject, NSMenuDelegate {
    static let shared = StatusItemController()

    private var statusItem: NSStatusItem?
    private let menu = NSMenu()
    private var hostingView: NSHostingView<AnyView>?
    private var cancellables: Set<AnyCancellable> = []
    private(set) var isMenuOpen = false

    func install() {
        guard statusItem == nil else { return }

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            let image = NSImage(systemSymbolName: "slider.vertical.3", accessibilityDescription: "PerAppVolume")
            image?.isTemplate = true
            button.image = image
        }

        let content = MenuContentView()
            .environmentObject(MixerModel.shared)
            .environmentObject(SystemVolume.shared)
            .environmentObject(Localizer.shared)
        let hosting = NSHostingView(rootView: AnyView(content))
        hostingView = hosting

        let contentItem = NSMenuItem()
        contentItem.view = hosting
        menu.addItem(contentItem)
        menu.delegate = self
        item.menu = menu
        statusItem = item

        resize()
        // Keep the menu the right height when apps appear/disappear or the language changes.
        MixerModel.shared.$apps.map { _ in () }
            .merge(with: Localizer.shared.$choice.map { _ in () })
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.resize() }
            .store(in: &cancellables)
    }

    /// Closes the menu, then runs `action` (used to open the mixer or settings windows).
    func closeMenu(then action: @escaping @MainActor () -> Void) {
        menu.cancelTracking()
        DispatchQueue.main.async { action() }
    }

    private func resize() {
        guard let hostingView else { return }
        hostingView.layoutSubtreeIfNeeded()
        let size = hostingView.fittingSize
        if hostingView.frame.size != size {
            hostingView.setFrameSize(size)
        }
    }

    // MARK: NSMenuDelegate

    func menuWillOpen(_ menu: NSMenu) {
        isMenuOpen = true
        MixerModel.shared.refresh()
        resize()
    }

    func menuDidClose(_ menu: NSMenu) {
        isMenuOpen = false
    }
}
