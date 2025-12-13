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
    public init(
        dataStore: DataStore,
        archiveStorage: ArchiveStorage = UserDefaultsArchiveStorage()
    ) {
        self.dataStore = dataStore
        self.archiveStorage = archiveStorage
    }

    // MARK: Public

    /// The list of visible (non-archived) projects
    public var projects: [Project] {
        filterArchivedProjects(from: dataStore.projects)
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

    // MARK: Private

    @ObservationIgnored private let dataStore: DataStore
    private let archiveStorage: ArchiveStorage

    /// Filter out archived projects
    private func filterArchivedProjects(from projects: [Project]) -> [Project] {
        let archivedIDs = archiveStorage.archivedProjectIDs()
        return projects.filter { !archivedIDs.contains($0.id) }
    }
}
