import AppKit
import Combine
import CoreAudio

/// Volume settings saved per app (by bundle identifier).
struct AppSetting: Codable, Equatable {
    var volume: Double = 1      // 0.0 ... 2.0
    var muted = false

    var isDefault: Bool { abs(volume - 1) < 0.001 && !muted }
    var gain: Float { muted ? 0 : Float(volume) }
}

struct AudioApp: Identifiable, Equatable {
    let id: String
    let name: String
    let path: String
    let isPlaying: Bool
}

@MainActor
final class MixerModel: ObservableObject {
    static let shared = MixerModel()

    @Published private(set) var apps: [AudioApp] = []
    @Published private(set) var settings: [String: AppSetting] = [:]
    @Published private(set) var errors: [String: String] = [:]

    private var scanned: [String: ScannedApp] = [:]
    private var taps: [String: AppTap] = [:]
    private var defaultSince: [String: Date] = [:]
    private var failedAt: [String: Date] = [:]
    private var seenThisSession: Set<String> = []
    private var deviceUID: String?
    private var iconCache: [String: NSImage] = [:]
    private var timer: Timer?
    private var started = false

    private let settingsKey = "appSettings"

    // MARK: Lifecycle

    func start() {
        guard !started else { return }
        started = true
        load()
        deviceUID = CA.defaultOutputDeviceUID()

        CA.addSystemListener(kAudioHardwarePropertyProcessObjectList) {
            Task { @MainActor in MixerModel.shared.refresh() }
        }
        CA.addSystemListener(kAudioHardwarePropertyDefaultOutputDevice) {
            Task { @MainActor in MixerModel.shared.outputDeviceChanged() }
        }
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            Task { @MainActor in MixerModel.shared.refresh() }
        }
        refresh()
    }

    func stopAll() {
        taps.values.forEach { $0.stop() }
        taps.removeAll()
    }

    // MARK: Queries

    func setting(for id: String) -> AppSetting { settings[id] ?? AppSetting() }

    func icon(for app: AudioApp) -> NSImage {
        if let icon = iconCache[app.path] { return icon }
        let icon = (useOriginalIcons ? Self.originalIcon(at: app.path) : nil) ?? NSWorkspace.shared.icon(forFile: app.path)
        iconCache[app.path] = icon
        return icon
    }

    // MARK: Actions

    func setVolume(_ volume: Double, for id: String) {
        var s = setting(for: id)
        s.volume = min(max(volume, 0), 2)
        if s.volume > 0 { s.muted = false }
        apply(s, to: id)
    }

    func toggleMute(for id: String) {
        var s = setting(for: id)
        s.muted.toggle()
        apply(s, to: id)
    }

    func reset(_ id: String) { apply(AppSetting(), to: id) }

    func resetAll() {
        for id in settings.keys { apply(AppSetting(), to: id) }
    }

    private func apply(_ s: AppSetting, to id: String) {
        if s.isDefault { settings.removeValue(forKey: id) } else { settings[id] = s }
        save()
        taps[id]?.gain.target = s.gain
        failedAt[id] = nil
        reconcile()
    }

    // MARK: Scanning & taps

    func refresh() {
        let list = AudioProcessScanner.scan()
        scanned = Dictionary(list.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        for app in list where app.isPlaying { seenThisSession.insert(app.id) }

        // Every open app (the ones with a Dock icon), plus background apps that play audio.
        let ownPID = ProcessInfo.processInfo.processIdentifier
        let openApps = NSWorkspace.shared.runningApplications.filter {
            $0.activationPolicy == .regular && $0.processIdentifier != ownPID && $0.bundleIdentifier != nil
        }
        let openIDs = Set(openApps.compactMap(\.bundleIdentifier))

        var entries: [String: AudioApp] = [:]
        for app in list where app.isPlaying || openIDs.contains(app.id)
            || seenThisSession.contains(app.id) || settings[app.id] != nil {
            entries[app.id] = AudioApp(id: app.id, name: app.name, path: app.path, isPlaying: app.isPlaying)
        }
        for running in openApps {
            guard let id = running.bundleIdentifier, entries[id] == nil, let url = running.bundleURL else { continue }
            let name = AudioProcessScanner.displayName(of: Bundle(url: url), path: url.path)
            entries[id] = AudioApp(id: id, name: name, path: url.path, isPlaying: false)
        }

        let visible = entries.values
            .sorted { lhs, rhs in
                if lhs.isPlaying != rhs.isPlaying { return lhs.isPlaying }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
        if visible != apps { apps = visible }
        reconcile()
    }

    private func outputDeviceChanged() {
        deviceUID = CA.defaultOutputDeviceUID()
        reconcile()   // taps on the old device are rebuilt on the new one
    }

    /// Makes the running taps match the settings: one tap per running app whose volume isn't 100%.
    private func reconcile() {
        let now = Date()
        let uid = deviceUID

        for (id, tap) in taps {
            guard let app = scanned[id], let uid else {
                tap.stop(); taps[id] = nil; continue
            }
            if setting(for: id).isDefault {
                // Wait a moment before removing, so dragging the slider across 100% doesn't glitch.
                let since = defaultSince[id] ?? now
                defaultSince[id] = since
                if now.timeIntervalSince(since) > 1.5 {
                    tap.stop(); taps[id] = nil; defaultSince[id] = nil
                }
                continue
            }
            defaultSince[id] = nil
            if tap.processIDs != app.processObjectIDs || tap.deviceUID != uid {
                tap.stop(); taps[id] = nil   // recreated below with the new processes / device
            }
        }

        guard let uid else { return }
        for (id, s) in settings where !s.isDefault && taps[id] == nil {
            guard let app = scanned[id] else { continue }
            if let failed = failedAt[id], now.timeIntervalSince(failed) < 10 { continue }
            do {
                taps[id] = try AppTap(processIDs: app.processObjectIDs, deviceUID: uid, gain: s.gain, name: app.name)
                errors[id] = nil
                failedAt[id] = nil
            } catch {
                errors[id] = error.localizedDescription
                failedAt[id] = now
            }
        }
        for id in errors.keys where settings[id] == nil { errors[id] = nil }
    }

    // MARK: Demo data (only used by `--screenshots`; never saved, never creates taps)

    /// Screenshots use each app's own .icns, so they don't depend on the Mac's tinted-icon setting.
    var useOriginalIcons = false

    private static func originalIcon(at path: String) -> NSImage? {
        guard let bundle = Bundle(path: path),
              var file = bundle.object(forInfoDictionaryKey: "CFBundleIconFile") as? String else { return nil }
        if !file.hasSuffix(".icns") { file += ".icns" }
        return NSImage(contentsOfFile: "\(path)/Contents/Resources/\(file)")
    }

    func loadDemo(apps: [AudioApp], settings: [String: AppSetting]) {
        self.apps = apps
        self.settings = settings
    }

    func setDemoSetting(_ setting: AppSetting, for id: String) {
        settings[id] = setting
    }

    // MARK: Persistence

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: settingsKey),
              let decoded = try? JSONDecoder().decode([String: AppSetting].self, from: data) else { return }
        settings = decoded.filter { !$0.value.isDefault }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: settingsKey)
        }
    }
}
