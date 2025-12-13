//
// ProjectListViewModel.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation
import NDKSwiftCore
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
    ///   - ndk: The NDK instance for fetching projects
    ///   - userPubkey: The pubkey of the authenticated user
    ///   - archiveStorage: Storage for archived project IDs
    public init(
        ndk: NDK,
        userPubkey: String,
        archiveStorage: ArchiveStorage = UserDefaultsArchiveStorage()
    ) {
        self.ndk = ndk
        self.userPubkey = userPubkey
        self.archiveStorage = archiveStorage
    }

    // MARK: Public

    /// The list of visible (non-archived) projects
    public private(set) var projects: [Project] = []

    /// Whether projects are currently being loaded
    public private(set) var isLoading = false

    /// The current error message, if any
    public private(set) var errorMessage: String?

    /// Load projects from Nostr
    public func loadProjects() async {
        // Clear error
        errorMessage = nil

        // Start loading
        isLoading = true

        defer {
            // Always stop loading when done
            isLoading = false
        }

        do {
            // Create filter for projects by this user
            let filter = Project.filter(for: userPubkey)

            // Subscribe to projects
            var projectsByID: [String: Project] = [:]
            var projectOrder: [String] = []

            let subscription = ndk.subscribeToEvents(filters: [filter])

            for try await event in subscription {
                // Try to parse as Project
                if let project = Project.from(event: event) {
                    // Update projects map (handles replaceable events)
                    if projectsByID[project.id] == nil {
                        projectOrder.append(project.id)
                    }
                    projectsByID[project.id] = project

                    // Update UI immediately as events arrive (maintaining order)
                    allProjects = projectOrder.compactMap { projectsByID[$0] }
                    projects = filterArchivedProjects(from: allProjects)
                }
            }

            // Subscription finished (after EOSE)
        } catch {
            // Set error message
            errorMessage = "Failed to load projects. Please try again."
        }
    }

    /// Refresh the project list
    public func refresh() async {
        await loadProjects()
    }

    /// Archive a project (hide from list)
    /// - Parameter id: The project ID to archive
    public func archiveProject(id: String) async {
        archiveStorage.archive(projectID: id)
        projects = filterArchivedProjects(from: allProjects)
    }

    /// Unarchive a project (restore to list)
    /// - Parameter id: The project ID to unarchive
    public func unarchiveProject(id: String) async {
        archiveStorage.unarchive(projectID: id)
        projects = filterArchivedProjects(from: allProjects)
    }

    // MARK: Internal

    let ndk: NDK

    // MARK: Private

    private let userPubkey: String
    private let archiveStorage: ArchiveStorage

    /// All projects including archived ones
    private var allProjects: [Project] = []

    /// Filter out archived projects
    private func filterArchivedProjects(from projects: [Project]) -> [Project] {
        let archivedIDs = archiveStorage.archivedProjectIDs()
        return projects.filter { !archivedIDs.contains($0.id) }
    }
}
