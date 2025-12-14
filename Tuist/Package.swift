// swift-tools-version: 6.0
import PackageDescription

#if TUIST
import ProjectDescription

let packageSettings = PackageSettings(
    productTypes: [
        // Use dynamic frameworks for proper module visibility across dependencies
        "NDKSwiftCore": .framework,
        "NDKSwiftNostrDB": .framework,
        "NDKSwiftTesting": .framework,
        "NDKSwiftUI": .framework,
        "ElevenLabsSwift": .framework,
        "WhisperKit": .framework,
    ]
)
#endif

// See PLAN.md Milestone 1 for NDKSwift integration.
let package = Package(
    name: "TENEXDependencies",
    dependencies: [
        .package(url: "https://github.com/pablof7z/NDKSwift.git", branch: "master"),
        .package(url: "https://github.com/elevenlabs/elevenlabs-swift.git", from: "1.0.0"),
        .package(url: "https://github.com/argmaxinc/WhisperKit.git", from: "0.5.0"),
    ]
)
