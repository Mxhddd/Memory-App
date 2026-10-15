// swift-tools-version:5.9
import PackageDescription

// Pure-Swift science engine: no UIKit/SwiftUI, so `swift test` runs on Linux and CI.
let package = Package(
    name: "MemoryCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "MemoryCore", targets: ["MemoryCore"]),
    ],
    targets: [
        .target(name: "MemoryCore"),
        .testTarget(name: "MemoryCoreTests", dependencies: ["MemoryCore"]),
    ]
)
