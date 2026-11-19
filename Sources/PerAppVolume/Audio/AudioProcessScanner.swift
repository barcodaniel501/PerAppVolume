import AppKit
import CoreAudio
import Darwin

/// One app (e.g. "Arc") and every audio process that belongs to it (main app + helpers).
struct ScannedApp: Equatable {
    let id: String              // bundle identifier (or path when there is none)
    let name: String
    let path: String            // path of the .app bundle
    var processObjectIDs: [AudioObjectID]
    var isPlaying: Bool
}

/// Lists the processes Core Audio knows about and groups them by the app bundle that contains them.
/// Helper processes (for example "Arc Helper", which plays the audio of web pages) live inside the
/// main app bundle, so the outermost `.app` in the executable path identifies the real app.
enum AudioProcessScanner {
    static func scan() -> [ScannedApp] {
        let ownPID = getpid()
        let ownBundle = Bundle.main.bundlePath
        var groups: [String: ScannedApp] = [:]

        for object in CA.objectList(CA.system, kAudioHardwarePropertyProcessObjectList) {
            guard let pid = CA.read(object, kAudioProcessPropertyPID, as: pid_t(0)), pid > 0, pid != ownPID,
                  let executable = executablePath(of: pid),
                  let appPath = outermostAppBundle(in: executable),
                  appPath != ownBundle
            else { continue }

            let playing = (CA.read(object, kAudioProcessPropertyIsRunningOutput, as: UInt32(0)) ?? 0) != 0
            let bundle = Bundle(path: appPath)
            let id = bundle?.bundleIdentifier ?? appPath

            if var group = groups[id] {
                group.processObjectIDs.append(object)
                group.isPlaying = group.isPlaying || playing
                groups[id] = group
            } else {
                groups[id] = ScannedApp(id: id,
                                        name: displayName(of: bundle, path: appPath),
                                        path: appPath,
                                        processObjectIDs: [object],
                                        isPlaying: playing)
            }
        }
        return groups.values.map { app in
            var app = app
            app.processObjectIDs.sort()
            return app
        }
    }

    static func displayName(of bundle: Bundle?, path: String) -> String {
        let info = bundle?.localizedInfoDictionary ?? [:]
        let fallback = bundle?.infoDictionary ?? [:]
        for key in ["CFBundleDisplayName", "CFBundleName"] {
            // Some apps (e.g. WhatsApp) include invisible direction marks in their name.
            if let raw = (info[key] ?? fallback[key]) as? String {
                let name = raw.trimmingCharacters(in: .whitespacesAndNewlines.union(.controlCharacters))
                if !name.isEmpty { return name }
            }
        }
        return ((path as NSString).lastPathComponent as NSString).deletingPathExtension
    }

    static func executablePath(of pid: pid_t) -> String? {
        var buffer = [CChar](repeating: 0, count: Int(MAXPATHLEN) * 4)
        let length = proc_pidpath(pid, &buffer, UInt32(buffer.count))
        guard length > 0 else { return nil }
        return String(cString: buffer)
    }

    static func outermostAppBundle(in path: String) -> String? {
        let components = (path as NSString).pathComponents
        guard let index = components.firstIndex(where: { $0.hasSuffix(".app") }) else { return nil }
        return NSString.path(withComponents: Array(components[0...index]))
    }
}
