import Foundation

// `PerAppVolume --list` prints the apps Core Audio sees (useful for troubleshooting).
if CommandLine.arguments.contains("--list") {
    let apps = AudioProcessScanner.scan().sorted { $0.name < $1.name }
    for app in apps {
        let state = app.isPlaying ? "playing" : "idle   "
        print("[\(state)] \(app.name)  (\(app.id))  processes: \(app.processObjectIDs.count)")
    }
    if apps.isEmpty { print("No audio processes found.") }
    exit(0)
}

// `PerAppVolume --screenshots <dir>` renders the README screenshots with demo data.
if let index = CommandLine.arguments.firstIndex(of: "--screenshots") {
    let dir = CommandLine.arguments.count > index + 1 ? CommandLine.arguments[index + 1] : "docs/screenshots"
    MainActor.assumeIsolated { ScreenshotGenerator.run(outputDir: dir) }
    exit(0)
}

PerAppVolumeApp.main()
