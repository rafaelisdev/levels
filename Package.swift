// swift-tools-version: 5.10
import PackageDescription

// Runs on macOS 11+. Per-app volume needs Core Audio process taps (macOS 14.2+);
// on older systems the app controls the output device volume only.
let package = Package(
    name: "Levels",
    platforms: [.macOS(.v11)],
    targets: [
        // Pure timing and DSP logic for multi-output sync. No AppKit, no Core Audio:
        // everything here is unit-tested.
        .target(
            name: "LevelsCore",
            path: "Sources/LevelsCore"
        ),
        .executableTarget(
            name: "Levels",
            dependencies: ["LevelsCore"],
            path: "Sources/Levels",
            linkerSettings: [
                .linkedFramework("CoreAudio"),
                .linkedFramework("AudioToolbox"),
                .linkedFramework("ServiceManagement"),
            ]
        ),
        .testTarget(
            name: "LevelsCoreTests",
            dependencies: ["LevelsCore"],
            path: "Tests/LevelsCoreTests"
        ),
    ]
)
