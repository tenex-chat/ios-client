//
// ProjectListViewModel.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation
import Observation
import TENEXCore

// MARK: - ProjectListViewModel

/// View model for the project list screen
@MainActor
@Observable
public final class ProjectListViewModel {
    // MARK: Lifecycle

    /// Initialize the project list view model
    /// - Parameters:
    ///   - dataStore: The centralized data store
    ///   - archiveStorage: Storage for archived project IDs
    ///   - groupStorage: Storage for project groups
    public init(
        dataStore: DataStore,
        archiveStorage: ArchiveStorage = UserDefaultsArchiveStorage(),
        groupStorage: ProjectGroupStorage = UserDefaultsProjectGroupStorage()
    ) {
        self.dataStore = dataStore
        self.archiveStorage = archiveStorage
        self.groupStorage = groupStorage
        selectedGroupID = groupStorage.getSelectedGroupID()
    }

    // MARK: Public

    /// The currently selected group ID (nil = show all projects)
    public var selectedGroupID: String?

    /// All project groups
    public var groups: [ProjectGroup] {
        groupStorage.getAllGroups()
    }

    /// The list of visible (non-archived) projects, filtered by selected group
    public var projects: [Project] {
        let allProjects = filterArchivedProjects(from: dataStore.projects)

        guard let groupID = selectedGroupID,
              let group = groups.first(where: { $0.id == groupID })
        else {
            return allProjects
        }

        return allProjects.filter { group.projectIDs.contains($0.id) }
    }

    /// Whether projects are currently being loaded
    public var isLoading: Bool {
        dataStore.isLoadingProjects
    }

    /// Archive a project (hide from list)
    /// - Parameter id: The project ID to archive
    public func archiveProject(id: String) async {
        archiveStorage.archive(projectID: id)
    }

    /// Unarchive a project (restore to list)
    /// - Parameter id: The project ID to unarchive
    public func unarchiveProject(id: String) async {
        archiveStorage.unarchive(projectID: id)
    }

    /// Select a project group (nil = show all projects)
    /// - Parameter groupID: The group ID to select, or nil for all projects
    public func selectGroup(_ groupID: String?) {
        selectedGroupID = groupID
        groupStorage.setSelectedGroupID(groupID)
    }

    /// Create a new project group
    /// - Parameters:
    ///   - name: Group name
    ///   - projectIDs: Project IDs to include
    public func createGroup(name: String, projectIDs: [String]) {
        let group = ProjectGroup(name: name, projectIDs: projectIDs)
        groupStorage.saveGroup(group)
    }

    /// Update an existing project group
    /// - Parameter group: The updated group
    public func updateGroup(_ group: ProjectGroup) {
        groupStorage.updateGroup(group)
    }

    /// Delete a project group
    /// - Parameter id: The group ID to delete
    public func deleteGroup(id: String) {
        groupStorage.deleteGroup(id: id)
    }

    // MARK: Private

    @ObservationIgnored private let dataStore: DataStore
    private let archiveStorage: ArchiveStorage
    private let groupStorage: ProjectGroupStorage

    /// Filter out archived projects
    private func filterArchivedProjects(from projects: [Project]) -> [Project] {
        let archivedIDs = archiveStorage.archivedProjectIDs()
        return projects.filter { !archivedIDs.contains($0.id) }
    }
}
