// swift-tools-version: 6.0
import PackageDescription

#if TUIST
import ProjectDescription

let packageSettings = PackageSettings(
    productTypes: [
        // Use dynamic frameworks for proper module visibility across dependencies
        "NDKSwift": .framework,
        "P256K": .framework,
        "libsecp256k1": .framework,
        "CryptoSwift": .framework,
    ]
)
#endif

// External dependencies will be added as local packages to work around Tuist limitations
// with packages that have non-standard source layouts (like CashuSwift).
// See PLAN.md Milestone 1 for NDKSwift integration.
let package = Package(
    name: "TENEXDependencies",
    dependencies: [
        .package(url: "https://github.com/pablof7z/NDKSwift", from: "0.1.0"),
        // Explicit secp256k1 dependency to ensure proper linking
        .package(url: "https://github.com/GigaBitcoin/secp256k1.swift.git", from: "0.21.0"),
    ]
)
