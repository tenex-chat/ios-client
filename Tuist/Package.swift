// swift-tools-version: 6.0
import PackageDescription

#if TUIST
import ProjectDescription

let packageSettings = PackageSettings(
    productTypes: [
        // Use dynamic frameworks for proper module visibility across dependencies
        "NDKSwiftCore": .framework,
        "NDKSwiftNostrDB": .framework,
    ]
)
#endif

// External dependencies will be added as local packages to work around Tuist limitations
// with packages that have non-standard source layouts (like CashuSwift).
// See PLAN.md Milestone 1 for NDKSwift integration.
let package = Package(
    name: "TENEXDependencies",
    dependencies: [
        .package(path: "/Users/pablofernandez/10x/NDKSwift-z94ws0/master"),
    ]
)
