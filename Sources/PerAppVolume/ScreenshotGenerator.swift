import AppKit
import ImageIO
import SwiftUI
import UniformTypeIdentifiers

/// `PerAppVolume --screenshots <dir>` renders the interface with demo data into PNG/GIF files
/// for the README (English + Spanish, light + dark). It never creates audio taps, never changes the
/// real volume and never saves anything to the user's settings.
@MainActor
enum ScreenshotGenerator {
    private struct DemoApp {
        let id, name, path: String
        let playing: Bool
        let setting: AppSetting
    }

    private static let demoApps: [DemoApp] = [
        DemoApp(id: "Cisco-Systems.Spark", name: "Webex", path: "/Applications/Webex.app",
                playing: true, setting: AppSetting(volume: 1.0)),
        DemoApp(id: "com.spotify.client", name: "Spotify", path: "/Applications/Spotify.app",
                playing: true, setting: AppSetting(volume: 0.8)),
        DemoApp(id: "net.whatsapp.WhatsApp", name: "WhatsApp", path: "/Applications/WhatsApp.app",
                playing: false, setting: AppSetting(volume: 1.0)),
        DemoApp(id: "company.thebrowser.Browser", name: "Arc", path: "/Applications/Arc.app",
                playing: false, setting: AppSetting(volume: 1.0)),
        DemoApp(id: "com.apple.Music", name: "Music", path: "/System/Applications/Music.app",
                playing: false, setting: AppSetting(volume: 1.0, muted: true)),
    ]

    static func run(outputDir: String) {
        let app = NSApplication.shared
        app.setActivationPolicy(.prohibited)

        let localizer = Localizer.shared
        localizer.persistChoice = false
        LaunchAtLogin.demoMode = true
        MixerModel.shared.useOriginalIcons = true

        let dir = URL(fileURLWithPath: outputDir, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        for language in [LanguageChoice.en, .es] {
            localizer.choice = language
            let suffix = language.rawValue
            let musicName = language == .es ? "Música" : "Music"
            let speakers = language == .es ? "Bocinas del MacBook Pro" : "MacBook Pro Speakers"

            // Static screenshots: Webex turned down, WhatsApp boosted, Music muted.
            loadDemo(musicName: musicName, speakers: speakers, webex: 0.3, whatsapp: 1.5)
            for dark in [false, true] {
                let mode = dark ? "dark" : "light"
                save(snapshot(MenuContentView(), dark: dark), to: dir.appendingPathComponent("menu-\(suffix)-\(mode).png"))
                save(snapshot(MixerWindowView().frame(width: 460, height: 470), dark: dark),
                     to: dir.appendingPathComponent("window-\(suffix)-\(mode).png"))
                save(snapshot(SettingsView(), dark: dark), to: dir.appendingPathComponent("settings-\(suffix)-\(mode).png"))
            }

            // Animated demo: Webex goes down from 100% to 30%, then WhatsApp up to 150%.
            loadDemo(musicName: musicName, speakers: speakers, webex: 1.0, whatsapp: 1.0)
            var frames: [(CGImage, Double)] = []
            func frame(_ delay: Double) {
                if let image = snapshot(MenuContentView(), dark: true, scale: 1) { frames.append((image, delay)) }
            }
            frame(1.2)
            for step in 1...18 {
                let t = ease(Double(step) / 18)
                MixerModel.shared.setDemoSetting(AppSetting(volume: 1.0 - 0.7 * t), for: "Cisco-Systems.Spark")
                frame(0.05)
            }
            frame(1.0)
            for step in 1...12 {
                let t = ease(Double(step) / 12)
                MixerModel.shared.setDemoSetting(AppSetting(volume: 1.0 + 0.5 * t), for: "net.whatsapp.WhatsApp")
                frame(0.05)
            }
            frame(2.4)
            saveGIF(frames, to: dir.appendingPathComponent("demo-\(suffix).gif"))
        }
        print("Screenshots written to \(dir.path)")
    }

    private static func loadDemo(musicName: String, speakers: String, webex: Double, whatsapp: Double) {
        var settings: [String: AppSetting] = [:]
        let apps = demoApps.map { demo -> AudioApp in
            var setting = demo.setting
            if demo.id == "Cisco-Systems.Spark" { setting.volume = webex }
            if demo.id == "net.whatsapp.WhatsApp" { setting.volume = whatsapp }
            settings[demo.id] = setting
            let name = demo.id == "com.apple.Music" ? musicName : demo.name
            return AudioApp(id: demo.id, name: name, path: demo.path, isPlaying: demo.playing)
        }
        MixerModel.shared.loadDemo(apps: apps, settings: settings)
        SystemVolume.shared.loadDemo(volume: 0.75, deviceName: speakers)
    }

    private static func ease(_ t: Double) -> Double { t < 0.5 ? 2 * t * t : 1 - pow(-2 * t + 2, 2) / 2 }

    // MARK: Rendering

    /// Renders a view (with a rounded card background) through AppKit, so native controls are drawn.
    private static func snapshot<V: View>(_ view: V, dark: Bool, scale: CGFloat = 2) -> CGImage? {
        // Rounded like the macOS 26 system menus and windows.
        let radius: CGFloat = 16
        let content = view
            .padding(.vertical, 5)   // NSMenu adds this inset around its content
            .background(Color(nsColor: .windowBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1))
            .padding(1)
            .environmentObject(MixerModel.shared)
            .environmentObject(SystemVolume.shared)
            .environmentObject(Localizer.shared)

        let appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        let hosting = NSHostingView(rootView: content)
        hosting.appearance = appearance
        let size = hosting.fittingSize
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        window.appearance = appearance
        window.isOpaque = false
        window.backgroundColor = .clear
        window.contentView = hosting
        hosting.frame = NSRect(origin: .zero, size: size)
        hosting.layoutSubtreeIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(0.15))

        var image: CGImage?
        appearance?.performAsCurrentDrawingAppearance {
            guard let rep = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) else { return }
            hosting.cacheDisplay(in: hosting.bounds, to: rep)
            image = rep.cgImage
        }
        window.close()
        guard let image else { return nil }
        return resized(image, width: Int(size.width * scale), height: Int(size.height * scale))
    }

    private static func resized(_ image: CGImage, width: Int, height: Int) -> CGImage? {
        if image.width == width && image.height == height { return image }
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()
    }

    private static func save(_ image: CGImage?, to url: URL) {
        guard let image else { print("Failed: \(url.lastPathComponent)"); return }
        let rep = NSBitmapImageRep(cgImage: image)
        try? rep.representation(using: .png, properties: [:])?.write(to: url)
        print("  \(url.lastPathComponent)  \(image.width)×\(image.height)")
    }

    private static func saveGIF(_ frames: [(CGImage, Double)], to url: URL) {
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.gif.identifier as CFString,
                                                                frames.count, nil) else { return }
        CGImageDestinationSetProperties(destination, [
            kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0],
        ] as CFDictionary)
        for (image, delay) in frames {
            CGImageDestinationAddImage(destination, image, [
                kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: delay],
            ] as CFDictionary)
        }
        CGImageDestinationFinalize(destination)
        print("  \(url.lastPathComponent)  \(frames.count) frames")
    }
}
