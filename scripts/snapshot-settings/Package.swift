// swift-tools-version: 6.0
// Renders the Settings window of the host app to PNG, light and dark, without any
// interaction, and checks every "keys → result" sample the window shows.
//
//   swift run --package-path scripts/snapshot-settings snapshot-settings <output-dir>
//   swift test --package-path scripts/snapshot-settings
//
// The app's view code is compiled straight from Apps/Dau/Sources (symlink "App"),
// minus its entry point. Not sandboxed, so it reads the real input-source shortcut;
// the "not enabled" banner is forced per screenshot.

import PackageDescription

let package = Package(
    name: "SnapshotSettings",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(path: "../../Packages/DauShared"),
    ],
    targets: [
        .executableTarget(
            name: "SnapshotSettings",
            dependencies: [.product(name: "DauShared", package: "DauShared")],
            exclude: ["App/main.swift", "App/DauApp.swift"]
        ),
        .testTarget(
            name: "SnapshotSettingsTests",
            dependencies: ["SnapshotSettings", .product(name: "DauShared", package: "DauShared")]
        ),
    ],
    swiftLanguageModes: [.v6]
)
