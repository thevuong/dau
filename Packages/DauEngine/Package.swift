// swift-tools-version: 6.0
// DauEngine: pure Swift Vietnamese input engine.
// Rule (CLAUDE.md, D10): sources in this package must not import Foundation or AppKit.

import PackageDescription

let package = Package(
    name: "DauEngine",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "DauEngine", targets: ["DauEngine"]),
    ],
    targets: [
        .target(name: "DauEngine"),
        .testTarget(name: "DauEngineTests", dependencies: ["DauEngine"]),
    ],
    swiftLanguageModes: [.v6]
)
