// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "Gridspace",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "MultitouchBridge"),
        .target(name: "GridCore"),
        .executableTarget(
            name: "Gridspace",
            dependencies: ["GridCore", "MultitouchBridge"]
        ),
        .testTarget(name: "GridCoreTests", dependencies: ["GridCore"]),
    ]
)
