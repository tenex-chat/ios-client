//
// KeychainStorage.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation
import Security
import TENEXCore

// MARK: - KeychainStorage

/// Secure storage for sensitive data using the iOS/macOS Keychain
public final class KeychainStorage: SecureStorage, @unchecked Sendable {
    // MARK: Lifecycle

    /// Initialize keychain storage with a specific service identifier
    /// - Parameter service: The service identifier for keychain items (defaults to "com.tenex.app")
    public init(service: String = "com.tenex.app") {
        self.service = service
    }

    // MARK: Public

    /// Errors that can occur during keychain operations
    public enum KeychainError: Error, LocalizedError {
        case encodingFailed
        case decodingFailed
        case unexpectedData
        case unhandledError(status: OSStatus)

        // MARK: Public

        public var errorDescription: String? {
            switch self {
            case .encodingFailed:
                "Failed to encode data for storage"
            case .decodingFailed:
                "Failed to decode data from keychain"
            case .unexpectedData:
                "Unexpected data format in keychain"
            case let .unhandledError(status):
                "Keychain error: \(status)"
            }
        }
    }

    // MARK: - Save

    /// Save a string value to the keychain
    /// - Parameters:
    ///   - value: The string value to save
    ///   - key: The key to associate with the value
    /// - Throws: KeychainError if the operation fails
    public func save(_ value: String, for key: String) throws {
        guard let data = value.data(using: .utf8) else {
            throw KeychainError.encodingFailed
        }

        // Create query
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]

        // Delete any existing item
        SecItemDelete(query as CFDictionary)

        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)

        guard status == errSecSuccess else {
            throw KeychainError.unhandledError(status: status)
        }
    }

    // MARK: - Retrieve

    /// Retrieve a string value from the keychain
    /// - Parameter key: The key associated with the value
    /// - Returns: The string value, or nil if not found
    /// - Throws: KeychainError if the operation fails
    public func retrieve(for key: String) throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status != errSecItemNotFound else {
            return nil
        }

        guard status == errSecSuccess else {
            throw KeychainError.unhandledError(status: status)
        }

        guard let data = result as? Data else {
            throw KeychainError.unexpectedData
        }

        guard let string = String(data: data, encoding: .utf8) else {
            throw KeychainError.decodingFailed
        }

        return string
    }

    // MARK: - Delete

    /// Delete a value from the keychain
    /// - Parameter key: The key associated with the value to delete
    /// - Throws: KeychainError if the operation fails
    public func delete(for key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]

        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unhandledError(status: status)
        }
    }

    // MARK: - Clear All

    /// Clear all keychain items for this service
    /// - Throws: KeychainError if the operation fails
    public func clearAll() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
        ]

        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unhandledError(status: status)
        }
    }

    // MARK: Private

    private let service: String
}
