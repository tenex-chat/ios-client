//
// TENEXFeatures.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation
import NDKSwiftCoreCore
import SwiftUI
import TENEXCore
import TENEXShared

// MARK: - NDKEnvironmentKey

private struct NDKEnvironmentKey: EnvironmentKey {
    static let defaultValue: NDK? = nil
}

public extension EnvironmentValues {
    /// The NDK instance for the current environment
    ///
    /// Use this to access the shared NDK instance from the environment:
    /// ```swift
    /// @Environment(\.ndk) private var ndk
    /// ```
    var ndk: NDK? {
        get { self[NDKEnvironmentKey.self] }
        set { self[NDKEnvironmentKey.self] = newValue }
    }
}

// MARK: - TENEXFeatures

/// TENEXFeatures module provides feature implementations for the TENEX app.
///
/// This module contains:
/// - Navigation: App routing and navigation shell
/// - Projects: Project list and management
/// - Threads: Thread list and navigation
/// - Chat: Message display and sending
/// - Voice: Voice mode with speech recognition
/// - Agents: Agent management and selection
/// - Documents: Document viewing
/// - Settings: App configuration
public enum TENEXFeatures {
    /// Current version of the TENEXFeatures module
    public static let version = "0.1.0"
}
