//
// ProjectGroupStorage.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation
import TENEXCore

// MARK: - ProjectGroupStorage

/// Protocol for storing project groups
public protocol ProjectGroupStorage: Sendable {
    /// Get all project groups
    func getAllGroups() -> [ProjectGroup]

    /// Save a new group
    func saveGroup(_ group: ProjectGroup)

    /// Update an existing group
    func updateGroup(_ group: ProjectGroup)

    /// Delete a group by ID
    func deleteGroup(id: String)

    /// Get the currently selected group ID
    func getSelectedGroupID() -> String?

    /// Set the currently selected group ID
    func setSelectedGroupID(_ id: String?)
}

// MARK: - UserDefaultsProjectGroupStorage

/// Project group storage backed by UserDefaults
public final class UserDefaultsProjectGroupStorage: ProjectGroupStorage, @unchecked Sendable {
    // MARK: Lifecycle

    public init(
        userDefaults: UserDefaults = .standard,
        groupsKey: String = "project_groups",
        selectedKey: String = "selected_project_group_id"
    ) {
        self.userDefaults = userDefaults
        self.groupsKey = groupsKey
        self.selectedKey = selectedKey
    }

    // MARK: Public

    public func getAllGroups() -> [ProjectGroup] {
        guard let data = userDefaults.data(forKey: groupsKey) else {
            return []
        }

        do {
            let groups = try JSONDecoder().decode([ProjectGroup].self, from: data)
            return groups.sorted { $0.createdAt < $1.createdAt }
        } catch {
            return []
        }
    }

    public func saveGroup(_ group: ProjectGroup) {
        var groups = getAllGroups()
        groups.append(group)
        saveAllGroups(groups)
    }

    public func updateGroup(_ group: ProjectGroup) {
        var groups = getAllGroups()
        if let index = groups.firstIndex(where: { $0.id == group.id }) {
            groups[index] = group
            saveAllGroups(groups)
        }
    }

    public func deleteGroup(id: String) {
        var groups = getAllGroups()
        groups.removeAll { $0.id == id }
        saveAllGroups(groups)

        // Clear selection if deleted group was selected
        if getSelectedGroupID() == id {
            setSelectedGroupID(nil)
        }
    }

    public func getSelectedGroupID() -> String? {
        userDefaults.string(forKey: selectedKey)
    }

    public func setSelectedGroupID(_ id: String?) {
        if let id {
            userDefaults.set(id, forKey: selectedKey)
        } else {
            userDefaults.removeObject(forKey: selectedKey)
        }
    }

    // MARK: Private

    private let userDefaults: UserDefaults
    private let groupsKey: String
    private let selectedKey: String

    private func saveAllGroups(_ groups: [ProjectGroup]) {
        do {
            let data = try JSONEncoder().encode(groups)
            userDefaults.set(data, forKey: groupsKey)
        } catch {
            // Silently fail - encoding should not crash the app
        }
    }
}

// MARK: - InMemoryProjectGroupStorage

/// In-memory project group storage for testing
public final class InMemoryProjectGroupStorage: ProjectGroupStorage, @unchecked Sendable {
    // MARK: Lifecycle

    public init() {}

    // MARK: Public

    public func getAllGroups() -> [ProjectGroup] {
        groups.sorted { $0.createdAt < $1.createdAt }
    }

    public func saveGroup(_ group: ProjectGroup) {
        groups.append(group)
    }

    public func updateGroup(_ group: ProjectGroup) {
        if let index = groups.firstIndex(where: { $0.id == group.id }) {
            groups[index] = group
        }
    }

    public func deleteGroup(id: String) {
        groups.removeAll { $0.id == id }

        // Clear selection if deleted group was selected
        if selectedGroupID == id {
            selectedGroupID = nil
        }
    }

    public func getSelectedGroupID() -> String? {
        selectedGroupID
    }

    public func setSelectedGroupID(_ id: String?) {
        selectedGroupID = id
    }

    // MARK: Private

    private var groups: [ProjectGroup] = []
    private var selectedGroupID: String?
}
