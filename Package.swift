// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TrafficLightsPlus",
    defaultLocalization: "zh-Hans",
    platforms: [.macOS("14.0")],
    dependencies: [.package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.10.1")],
    targets: [
        .executableTarget(
            name: "TrafficLightsPlus",
            dependencies: [.product(name: "Sparkle", package: "Sparkle")],
            path: "Sources/TrafficLightsPlus",
            resources: [.process("Resources"), .copy("WindowControlsComposite")],
            linkerSettings: [.unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])]
        ),
        .testTarget(
            name: "TrafficLightsPlusTests",
            dependencies: ["TrafficLightsPlus"],
            path: "Tests/TrafficLightsPlusTests"
        )
    ]
)
