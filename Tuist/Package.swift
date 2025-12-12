// swift-tools-version: 6.0
import PackageDescription

#if TUIST
import ProjectDescription

let packageSettings = PackageSettings(
    productTypes: [
        "NDKSwift": .framework,
        "NDKSwiftCore": .framework,
        "NDKSwiftUI": .framework,
    ]
)
#endif

let package = Package(
    name: "TENEXDependencies",
    dependencies: [
        .package(url: "https://github.com/AgoraLabsAI/NDKSwift.git", branch: "main"),
        .package(url: "https://github.com/nicklockwood/SwiftFormat", from: "0.54.0"),
        .package(url: "https://github.com/argmaxinc/WhisperKit.git", from: "0.9.0"),
    ]
)
