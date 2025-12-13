//
// ArchiveStorage.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation

// MARK: - ArchiveStorage

/// Protocol for storing archived project IDs
public protocol ArchiveStorage: Sendable {
    /// Check if a project is archived
    func isArchived(projectID: String) -> Bool

    /// Archive a project
    func archive(projectID: String)

    /// Unarchive a project
    func unarchive(projectID: String)

    /// Get all archived project IDs
    func archivedProjectIDs() -> Set<String>
}

// MARK: - UserDefaultsArchiveStorage

/// Archive storage backed by UserDefaults
public final class UserDefaultsArchiveStorage: ArchiveStorage, @unchecked Sendable {
    // MARK: Lifecycle

    public init(userDefaults: UserDefaults = .standard, key: String = "archived_project_ids") {
        self.userDefaults = userDefaults
        self.key = key
    }

    // MARK: Public

    public func isArchived(projectID: String) -> Bool {
        archivedProjectIDs().contains(projectID)
    }

    public func archive(projectID: String) {
        var archived = archivedProjectIDs()
        archived.insert(projectID)
        saveArchivedIDs(archived)
    }

    public func unarchive(projectID: String) {
        var archived = archivedProjectIDs()
        archived.remove(projectID)
        saveArchivedIDs(archived)
    }

    public func archivedProjectIDs() -> Set<String> {
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

// MARK: - InMemoryArchiveStorage

/// In-memory archive storage for testing
public final class InMemoryArchiveStorage: ArchiveStorage, @unchecked Sendable {
    // MARK: Lifecycle

    public init() {}

    // MARK: Public

    public func isArchived(projectID: String) -> Bool {
        archivedIDs.contains(projectID)
    }

    public func archive(projectID: String) {
        archivedIDs.insert(projectID)
    }

    public func unarchive(projectID: String) {
        archivedIDs.remove(projectID)
    }

    public func archivedProjectIDs() -> Set<String> {
        archivedIDs
    }

    // MARK: Private

    private var archivedIDs: Set<String> = []
}
