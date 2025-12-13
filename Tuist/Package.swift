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
        // Note: NDKSwiftUI excluded due to upstream bug (relayUrls: vs relayURLs:)
    ]
)
#endif

// External dependencies will be added as local packages to work around Tuist limitations
// with packages that have non-standard source layouts (like CashuSwift).
// See PLAN.md Milestone 1 for NDKSwift integration.
let package = Package(
    name: "TENEXDependencies",
    dependencies: [
        .package(url: "https://github.com/pablof7z/NDKSwift.git", branch: "master"),
        .package(url: "https://github.com/argmaxinc/WhisperKit.git", from: "0.9.0"),
    ]
)
