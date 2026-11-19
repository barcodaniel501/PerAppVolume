// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "PerAppVolume",
    platforms: [.macOS("14.2")],
    targets: [
        .executableTarget(
            name: "PerAppVolume",
            path: "Sources/PerAppVolume",
            linkerSettings: [
                .linkedFramework("CoreAudio"),
                .linkedFramework("AudioToolbox"),
                .linkedFramework("ServiceManagement"),
            ]
        ),
    ]
)
