// swift-tools-version: 5.10
import PackageDescription

// CrearoCore — platform-agnostic game logic for Crearo.
// Intentionally depends ONLY on Foundation so it builds & unit-tests on Linux CI
// without a simulator (see docs/TECH_ARCHITECTURE.md §9). No SwiftUI/RealityKit/UIKit here.
let package = Package(
    name: "CrearoCore",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "CrearoCore", targets: ["CrearoCore"])
    ],
    targets: [
        .target(
            name: "CrearoCore",
            path: "Sources/CrearoCore"
        ),
        .testTarget(
            name: "CrearoCoreTests",
            dependencies: ["CrearoCore"],
            path: "Tests/CrearoCoreTests"
        )
    ]
)
