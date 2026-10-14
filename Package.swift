// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "Gridspace",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "MultitouchBridge"),
        .target(
            name: "ISS",
            exclude: ["LICENSE", "README.md"],
            linkerSettings: [.linkedFramework("ApplicationServices"), .linkedFramework("IOKit")]
        ),
        .target(name: "GridCore"),
        .executableTarget(
            name: "Gridspace",
            dependencies: ["GridCore", "MultitouchBridge", "ISS"]
        ),
        .testTarget(name: "GridCoreTests", dependencies: ["GridCore"]),
        .testTarget(name: "GestureRecognizerTests", dependencies: ["MultitouchBridge"]),
    ]
)
