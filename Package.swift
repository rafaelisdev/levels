// swift-tools-version: 5.10
import PackageDescription

// Runs on macOS 11+. Per-app volume needs Core Audio process taps (macOS 14.2+);
// on older systems the app controls the output device volume only.
let package = Package(
    name: "VolumeMixer",
    platforms: [.macOS(.v11)],
    targets: [
        .executableTarget(
            name: "VolumeMixer",
            path: "Sources/VolumeMixer",
            linkerSettings: [
                .linkedFramework("CoreAudio"),
                .linkedFramework("AudioToolbox"),
                .linkedFramework("ServiceManagement"),
            ]
        )
    ]
)
