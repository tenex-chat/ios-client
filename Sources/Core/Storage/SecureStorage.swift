//
// SecureStorage.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation

// MARK: - SecureStorage

/// Protocol for secure storage operations
public protocol SecureStorage: Sendable {
    /// Save a string value to secure storage
    /// - Parameters:
    ///   - value: The string value to save
    ///   - key: The key to associate with the value
    /// - Throws: Error if the operation fails
    func save(_ value: String, for key: String) throws

    /// Retrieve a string value from secure storage
    /// - Parameter key: The key associated with the value
    /// - Returns: The string value, or nil if not found
    /// - Throws: Error if the operation fails
    func retrieve(for key: String) throws -> String?

    /// Delete a value from secure storage
    /// - Parameter key: The key associated with the value to delete
    /// - Throws: Error if the operation fails
    func delete(for key: String) throws

    /// Clear all items from secure storage
    /// - Throws: Error if the operation fails
    func clearAll() throws
}
