//
// BlossomSettings.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation

// MARK: - BlossomSettings

/// Settings for Blossom file uploads
@MainActor
@Observable
public final class BlossomSettings {
    // MARK: - Constants

    /// Default Blossom server URL
    public static let defaultServerURL = "https://blossom.primal.net"
    private static let serverURLKey = "blossom-server-url"

    // MARK: - Properties

    private let userDefaults: UserDefaults

    /// The configured Blossom server URL
    public var serverURL: String {
        didSet {
            userDefaults.set(serverURL, forKey: Self.serverURLKey)
        }
    }

    // MARK: - Initialization

    /// Initialize with user defaults storage
    /// - Parameter userDefaults: UserDefaults instance for persistence
    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        serverURL = userDefaults.string(forKey: Self.serverURLKey) ?? Self.defaultServerURL
    }

    // MARK: - Public Methods

    /// Reset to default server URL
    public func resetToDefault() {
        serverURL = Self.defaultServerURL
    }

    /// Check if using the default server
    public var isUsingDefaultServer: Bool {
        serverURL == Self.defaultServerURL
    }
}
