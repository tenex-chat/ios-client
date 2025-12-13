//
//  Project.swift
//  TENEX
//

import ProjectDescription

// MARK: - Project

let project = Project(
    name: "TENEX",
    organizationName: "TENEX",
    options: .options(
        automaticSchemesOptions: .disabled,
        disableBundleAccessors: false,
        disableSynthesizedResourceAccessors: false,
        textSettings: .textSettings(
            indentWidth: 4,
            tabWidth: 4,
            wrapsLines: true
        )
    ),
    settings: .settings(
        base: [
            "SWIFT_STRICT_CONCURRENCY": "complete",
            "ENABLE_USER_SCRIPT_SANDBOXING": "NO",
            "CODE_SIGN_STYLE": "Automatic",
            "DEVELOPMENT_TEAM": "456SHKPP26",
        ],
        configurations: [
            .debug(name: "Debug", settings: ["SWIFT_ACTIVE_COMPILATION_CONDITIONS": "DEBUG"]),
            .release(name: "Release", settings: [:]),
        ]
    ),
    targets: [
        // MARK: - Main App

        .target(
            name: "TENEX",
            destinations: [.iPhone, .iPad, .mac],
            product: .app,
            bundleId: "chat.tenex.ios",
            deploymentTargets: .multiplatform(iOS: "17.0", macOS: "14.0"),
            infoPlist: .extendingDefault(with: [
                "CFBundleDisplayName": "TENEX",
                "UILaunchScreen": [:],
                "NSMicrophoneUsageDescription": "TENEX needs microphone access for voice conversations with agents.",
                "NSSpeechRecognitionUsageDescription": "TENEX uses speech recognition for voice input.",
                "UIBackgroundModes": ["audio"],
            ]),
            sources: ["Sources/App/**"],
            resources: ["Resources/**"],
            scripts: [
                .pre(
                    script: """
                    export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
                    if command -v swiftlint >/dev/null 2>&1; then
                        cd "$SRCROOT" && swiftlint --strict Sources/App
                    else
                        echo "error: SwiftLint not installed. Install via 'brew install swiftlint'"
                        exit 1
                    fi
                    """,
                    name: "SwiftLint",
                    basedOnDependencyAnalysis: false
                )
            ],
            dependencies: [
                .target(name: "TENEXCore"),
                .target(name: "TENEXFeatures"),
                .target(name: "TENEXShared"),
            ]
        ),

        // MARK: - Core Module

        .target(
            name: "TENEXCore",
            destinations: [.iPhone, .iPad, .mac],
            product: .framework,
            bundleId: "chat.tenex.ios.core",
            deploymentTargets: .multiplatform(iOS: "17.0", macOS: "14.0"),
            sources: ["Sources/Core/**"],
            scripts: [
                .pre(
                    script: """
                    export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
                    if command -v swiftlint >/dev/null 2>&1; then
                        cd "$SRCROOT" && swiftlint --strict Sources/Core
                    else
                        echo "error: SwiftLint not installed. Install via 'brew install swiftlint'"
                        exit 1
                    fi
                    """,
                    name: "SwiftLint",
                    basedOnDependencyAnalysis: false
                )
            ],
            dependencies: [
                .external(name: "NDKSwiftCore"),
                .external(name: "NDKSwiftNostrDB"),
                .external(name: "WhisperKit"),
                .target(name: "TENEXShared"),
            ]
        ),

        // MARK: - Features Module (umbrella)

        .target(
            name: "TENEXFeatures",
            destinations: [.iPhone, .iPad, .mac],
            product: .framework,
            bundleId: "chat.tenex.ios.features",
            deploymentTargets: .multiplatform(iOS: "17.0", macOS: "14.0"),
            sources: ["Sources/Features/**"],
            scripts: [
                .pre(
                    script: """
                    export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
                    if command -v swiftlint >/dev/null 2>&1; then
                        cd "$SRCROOT" && swiftlint --strict Sources/Features
                    else
                        echo "error: SwiftLint not installed. Install via 'brew install swiftlint'"
                        exit 1
                    fi
                    """,
                    name: "SwiftLint",
                    basedOnDependencyAnalysis: false
                )
            ],
            dependencies: [
                .target(name: "TENEXCore"),
                .target(name: "TENEXShared"),
            ]
        ),

        // MARK: - Shared Module

        .target(
            name: "TENEXShared",
            destinations: [.iPhone, .iPad, .mac],
            product: .framework,
            bundleId: "chat.tenex.ios.shared",
            deploymentTargets: .multiplatform(iOS: "17.0", macOS: "14.0"),
            sources: ["Sources/Shared/**"],
            scripts: [
                .pre(
                    script: """
                    export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
                    if command -v swiftlint >/dev/null 2>&1; then
                        cd "$SRCROOT" && swiftlint --strict Sources/Shared
                    else
                        echo "error: SwiftLint not installed. Install via 'brew install swiftlint'"
                        exit 1
                    fi
                    """,
                    name: "SwiftLint",
                    basedOnDependencyAnalysis: false
                )
            ],
            dependencies: []
        ),

        // MARK: - Unit Tests - iOS

        .target(
            name: "TENEXCoreTests-iOS",
            destinations: [.iPhone, .iPad],
            product: .unitTests,
            bundleId: "chat.tenex.ios.core.tests.ios",
            deploymentTargets: .iOS("17.0"),
            sources: ["Tests/CoreTests/**"],
            dependencies: [
                .target(name: "TENEXCore"),
                .external(name: "NDKSwiftCore"),
                .external(name: "NDKSwiftNostrDB"),
                .external(name: "NDKSwiftTesting"),
            ]
        ),

        .target(
            name: "TENEXFeaturesTests-iOS",
            destinations: [.iPhone, .iPad],
            product: .unitTests,
            bundleId: "chat.tenex.ios.features.tests.ios",
            deploymentTargets: .iOS("17.0"),
            sources: ["Tests/FeaturesTests/**", "Tests/TestHelpers/**"],
            dependencies: [
                .target(name: "TENEXFeatures"),
                .target(name: "TENEXCore"),
                .external(name: "NDKSwiftTesting"),
            ]
        ),

        .target(
            name: "TENEXSharedTests-iOS",
            destinations: [.iPhone, .iPad],
            product: .unitTests,
            bundleId: "chat.tenex.ios.shared.tests.ios",
            deploymentTargets: .iOS("17.0"),
            sources: ["Tests/SharedTests/**"],
            dependencies: [
                .target(name: "TENEXShared"),
            ]
        ),

        // MARK: - Unit Tests - macOS

        .target(
            name: "TENEXCoreTests-macOS",
            destinations: [.mac],
            product: .unitTests,
            bundleId: "chat.tenex.ios.core.tests.macos",
            deploymentTargets: .macOS("14.0"),
            sources: ["Tests/CoreTests/**"],
            dependencies: [
                .target(name: "TENEXCore"),
                .external(name: "NDKSwiftCore"),
                .external(name: "NDKSwiftNostrDB"),
                .external(name: "NDKSwiftTesting"),
            ]
        ),

        .target(
            name: "TENEXFeaturesTests-macOS",
            destinations: [.mac],
            product: .unitTests,
            bundleId: "chat.tenex.ios.features.tests.macos",
            deploymentTargets: .macOS("14.0"),
            sources: ["Tests/FeaturesTests/**", "Tests/TestHelpers/**"],
            dependencies: [
                .target(name: "TENEXFeatures"),
                .target(name: "TENEXCore"),
                .external(name: "NDKSwiftTesting"),
            ]
        ),

        .target(
            name: "TENEXSharedTests-macOS",
            destinations: [.mac],
            product: .unitTests,
            bundleId: "chat.tenex.ios.shared.tests.macos",
            deploymentTargets: .macOS("14.0"),
            sources: ["Tests/SharedTests/**"],
            dependencies: [
                .target(name: "TENEXShared"),
            ]
        ),

        // MARK: - UI Tests

        .target(
            name: "TENEXUITests",
            destinations: [.iPhone, .iPad],
            product: .uiTests,
            bundleId: "chat.tenex.ios.uitests",
            deploymentTargets: .iOS("17.0"),
            sources: ["Tests/UITests/**"],
            dependencies: [
                .target(name: "TENEX"),
            ]
        ),
    ],
    schemes: [
        .scheme(
            name: "TENEX",
            shared: true,
            buildAction: .buildAction(targets: ["TENEX"]),
            testAction: .targets([
                .testableTarget(target: .target("TENEXCoreTests-iOS")),
                .testableTarget(target: .target("TENEXFeaturesTests-iOS")),
                .testableTarget(target: .target("TENEXSharedTests-iOS")),
            ]),
            runAction: .runAction(executable: "TENEX"),
            archiveAction: .archiveAction(configuration: "Release"),
            profileAction: .profileAction(executable: "TENEX"),
            analyzeAction: .analyzeAction(configuration: "Debug")
        ),
        .scheme(
            name: "TENEX-Tests-iOS",
            shared: true,
            buildAction: .buildAction(targets: [
                "TENEXCoreTests-iOS",
                "TENEXFeaturesTests-iOS",
                "TENEXSharedTests-iOS",
            ]),
            testAction: .targets([
                .testableTarget(target: .target("TENEXCoreTests-iOS")),
                .testableTarget(target: .target("TENEXFeaturesTests-iOS")),
                .testableTarget(target: .target("TENEXSharedTests-iOS")),
            ])
        ),
        .scheme(
            name: "TENEX-Tests-macOS",
            shared: true,
            buildAction: .buildAction(targets: [
                "TENEXCoreTests-macOS",
                "TENEXFeaturesTests-macOS",
                "TENEXSharedTests-macOS",
            ]),
            testAction: .targets([
                .testableTarget(target: .target("TENEXCoreTests-macOS")),
                .testableTarget(target: .target("TENEXFeaturesTests-macOS")),
                .testableTarget(target: .target("TENEXSharedTests-macOS")),
            ])
        ),
    ],
    additionalFiles: [
        "PLAN.md",
        "CONTRIBUTING.md",
        "README.md",
        ".swiftlint.yml",
        ".swiftformat",
    ]
)
