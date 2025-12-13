//
// InMemorySecureStorage.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation
@testable import TENEXCore
@testable import TENEXFeatures

/// In-memory implementation of SecureStorage for testing
@MainActor
public final class InMemorySecureStorage: SecureStorage {
    // MARK: Lifecycle

    public init() {
        storage = [:]
    }

    // MARK: Public

    public func save(_ value: String, for key: String) throws {
        storage[key] = value
    }

    public func retrieve(for key: String) throws -> String? {
        storage[key]
    }

    public func delete(for key: String) throws {
        storage.removeValue(forKey: key)
    }

    public func clearAll() throws {
        storage.removeAll()
    }

    // MARK: Private

    private var storage: [String: String]
}
