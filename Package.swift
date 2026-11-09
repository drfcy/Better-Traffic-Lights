// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TrafficLightsPlus",
    defaultLocalization: "zh-Hans",
    platforms: [.macOS("14.0")],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "TrafficLightsPlus",
            dependencies: [],
            path: "Sources/TrafficLightsPlus",
            resources: [.process("Resources"), .copy("WindowControlsComposite")]
        ),
        .testTarget(
            name: "TrafficLightsPlusTests",
            dependencies: ["TrafficLightsPlus"],
            path: "Tests/TrafficLightsPlusTests"
        )
    ]
)
