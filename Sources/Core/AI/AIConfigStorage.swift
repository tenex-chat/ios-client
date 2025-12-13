//
// AIConfigStorage.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation

// MARK: - AIConfigStorage

/// Protocol for AI configuration storage operations
public protocol AIConfigStorage: Sendable {
    /// Save AI configuration
    /// - Parameter config: The configuration to save
    /// - Throws: Error if the operation fails
    func save(_ config: AIConfig) throws

    /// Load AI configuration
    /// - Returns: The saved configuration, or nil if none exists
    /// - Throws: Error if the operation fails
    func load() throws -> AIConfig?

    /// Clear all AI configuration
    /// - Throws: Error if the operation fails
    func clear() throws

    /// Save API key for a specific configuration
    /// - Parameters:
    ///   - key: The API key to save
    ///   - configID: The configuration ID
    /// - Throws: Error if the operation fails
    func saveAPIKey(_ key: String, for configID: String) throws

    /// Load API key for a specific configuration
    /// - Parameter configID: The configuration ID
    /// - Returns: The API key, or nil if not found
    /// - Throws: Error if the operation fails
    func loadAPIKey(for configID: String) throws -> String?

    /// Delete API key for a specific configuration
    /// - Parameter configID: The configuration ID
    /// - Throws: Error if the operation fails
    func deleteAPIKey(for configID: String) throws
}

// MARK: - UserDefaultsAIConfigStorage

/// AI configuration storage using UserDefaults and Keychain
@MainActor
public final class UserDefaultsAIConfigStorage: AIConfigStorage {
    // MARK: Lifecycle

    /// Initialize storage with UserDefaults and Keychain
    /// - Parameters:
    ///   - keychain: Secure storage for API keys
    ///   - userDefaults: UserDefaults instance (defaults to .standard)
    public init(keychain: SecureStorage, userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        self.keychain = keychain
    }

    // MARK: Public

    public func save(_ config: AIConfig) throws {
        let encoder = JSONEncoder()
        let data = try encoder.encode(config)
        userDefaults.set(data, forKey: configKey)
    }

    public func load() throws -> AIConfig? {
        guard let data = userDefaults.data(forKey: configKey) else {
            return nil
        }

        let decoder = JSONDecoder()
        return try decoder.decode(AIConfig.self, from: data)
    }

    public func clear() throws {
        userDefaults.removeObject(forKey: configKey)
    }

    public func saveAPIKey(_ key: String, for configID: String) throws {
        let keychainKey = apiKeyKey(for: configID)
        try keychain.save(key, for: keychainKey)
    }

    public func loadAPIKey(for configID: String) throws -> String? {
        let keychainKey = apiKeyKey(for: configID)
        return try keychain.retrieve(for: keychainKey)
    }

    public func deleteAPIKey(for configID: String) throws {
        let keychainKey = apiKeyKey(for: configID)
        try keychain.delete(for: keychainKey)
    }

    // MARK: Private

    private let userDefaults: UserDefaults
    private let keychain: SecureStorage
    private let configKey = "ai-config-v1"

    private func apiKeyKey(for configID: String) -> String {
        "ai-api-key-\(configID)"
    }
}

// MARK: - InMemoryAIConfigStorage

/// In-memory AI configuration storage for testing
public final class InMemoryAIConfigStorage: AIConfigStorage {
    // MARK: Lifecycle

    public init() {}

    // MARK: Public

    public func save(_ config: AIConfig) throws {
        self.config = config
    }

    public func load() throws -> AIConfig? {
        config
    }

    public func clear() throws {
        config = nil
        apiKeys.removeAll()
    }

    public func saveAPIKey(_ key: String, for configID: String) throws {
        apiKeys[configID] = key
    }

    public func loadAPIKey(for configID: String) throws -> String? {
        apiKeys[configID]
    }

    public func deleteAPIKey(for configID: String) throws {
        apiKeys.removeValue(forKey: configID)
    }

    // MARK: Private

    private var config: AIConfig?
    private var apiKeys: [String: String] = [:]
}
