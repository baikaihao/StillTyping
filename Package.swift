// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "StillTyping",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "StillTyping", targets: ["StillTyping"])],
    targets: [
        .target(name: "StillTypingCore"),
        .executableTarget(
            name: "StillTyping",
            dependencies: ["StillTypingCore"],
            resources: [.copy("Resources"), .process("Localization"), .process("Assets.xcassets")],
            swiftSettings: [.defaultIsolation(MainActor.self)]
        ),
        .testTarget(name: "StillTypingCoreTests", dependencies: ["StillTypingCore"])
    ]
)
