//
// ThreadArchiveStorage.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation

// MARK: - ThreadArchiveStorage

/// Protocol for storing archived thread IDs
public protocol ThreadArchiveStorage: Sendable {
    /// Check if a thread is archived
    func isArchived(threadID: String) -> Bool

    /// Archive a thread
    func archive(threadID: String)

    /// Unarchive a thread
    func unarchive(threadID: String)

    /// Get all archived thread IDs
    func archivedThreadIDs() -> Set<String>
}

// MARK: - UserDefaultsThreadArchiveStorage

/// Thread archive storage backed by UserDefaults
public final class UserDefaultsThreadArchiveStorage: ThreadArchiveStorage, @unchecked Sendable {
    // MARK: Lifecycle

    public init(userDefaults: UserDefaults = .standard, key: String = "archived_thread_ids") {
        self.userDefaults = userDefaults
        self.key = key
    }

    // MARK: Public

    public func isArchived(threadID: String) -> Bool {
        archivedThreadIDs().contains(threadID)
    }

    public func archive(threadID: String) {
        var archived = archivedThreadIDs()
        archived.insert(threadID)
        saveArchivedIDs(archived)
    }

    public func unarchive(threadID: String) {
        var archived = archivedThreadIDs()
        archived.remove(threadID)
        saveArchivedIDs(archived)
    }

    public func archivedThreadIDs() -> Set<String> {
        guard let array = userDefaults.array(forKey: key) as? [String] else {
            return []
        }
        return Set(array)
    }

    // MARK: Private

    private let userDefaults: UserDefaults
    private let key: String

    private func saveArchivedIDs(_ ids: Set<String>) {
        userDefaults.set(Array(ids), forKey: key)
    }
}

// MARK: - InMemoryThreadArchiveStorage

/// In-memory thread archive storage for testing
public final class InMemoryThreadArchiveStorage: ThreadArchiveStorage, @unchecked Sendable {
    // MARK: Lifecycle

    public init() {}

    // MARK: Public

    public func isArchived(threadID: String) -> Bool {
        archivedIDs.contains(threadID)
    }

    public func archive(threadID: String) {
        archivedIDs.insert(threadID)
    }

    public func unarchive(threadID: String) {
        archivedIDs.remove(threadID)
    }

    public func archivedThreadIDs() -> Set<String> {
        archivedIDs
    }

    // MARK: Private

    private var archivedIDs: Set<String> = []
}
