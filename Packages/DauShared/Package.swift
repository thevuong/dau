// swift-tools-version: 6.0
// DauShared: code shared by the host app and the input method
// (settings keys, compatibility list model and signature check).

import PackageDescription

let package = Package(
    name: "DauShared",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "DauShared", targets: ["DauShared"]),
    ],
    targets: [
        .target(name: "DauShared"),
        .testTarget(name: "DauSharedTests", dependencies: ["DauShared"]),
    ],
    swiftLanguageModes: [.v6]
)
