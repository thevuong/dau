// swift-tools-version: 6.0
// DauShared: code shared by the host app and the input method
// (settings model and store, compatibility list model and signature check).
//
// Depends on DauEngine so both apps map settings to `EngineOptions` the same way and the
// host app can drive the real engine for its previews. DauEngine itself stays free of
// Foundation; this package may use Foundation (UserDefaults, Codable).

import PackageDescription

let package = Package(
    name: "DauShared",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "DauShared", targets: ["DauShared"]),
    ],
    dependencies: [
        .package(path: "../DauEngine"),
    ],
    targets: [
        .target(name: "DauShared", dependencies: ["DauEngine"]),
        .testTarget(name: "DauSharedTests", dependencies: ["DauShared", "DauEngine"]),
    ],
    swiftLanguageModes: [.v6]
)
