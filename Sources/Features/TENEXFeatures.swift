//
// TENEXFeatures.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation
import NDKSwiftCore
import SwiftUI
import TENEXCore
import TENEXShared

// MARK: - NDKEnvironmentKey

private struct NDKEnvironmentKey: EnvironmentKey {
    static let defaultValue: NDK? = nil
}

// MARK: - AIConfigEnvironmentKey

private struct AIConfigEnvironmentKey: EnvironmentKey {
    static let defaultValue: AIConfig? = nil
}

// MARK: - AIConfigStorageEnvironmentKey

private struct AIConfigStorageEnvironmentKey: EnvironmentKey {
    static let defaultValue: AIConfigStorage? = nil
}

// MARK: - AudioServiceEnvironmentKey

private struct AudioServiceEnvironmentKey: EnvironmentKey {
    static let defaultValue: AudioService? = nil
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

    /// The AI configuration for the current environment
    ///
    /// Use this to access the shared AI configuration from the environment:
    /// ```swift
    /// @Environment(\.aiConfig) private var aiConfig
    /// ```
    var aiConfig: AIConfig? {
        get { self[AIConfigEnvironmentKey.self] }
        set { self[AIConfigEnvironmentKey.self] = newValue }
    }

    /// The AI configuration storage for the current environment
    ///
    /// Use this to access the AI configuration storage from the environment:
    /// ```swift
    /// @Environment(\.aiConfigStorage) private var aiConfigStorage
    /// ```
    var aiConfigStorage: AIConfigStorage? {
        get { self[AIConfigStorageEnvironmentKey.self] }
        set { self[AIConfigStorageEnvironmentKey.self] = newValue }
    }

    /// The audio service for the current environment
    ///
    /// Use this to access the audio service from the environment:
    /// ```swift
    /// @Environment(\.audioService) private var audioService
    /// ```
    var audioService: AudioService? {
        get { self[AudioServiceEnvironmentKey.self] }
        set { self[AudioServiceEnvironmentKey.self] = newValue }
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
