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

PerAppVolumeApp.main()
