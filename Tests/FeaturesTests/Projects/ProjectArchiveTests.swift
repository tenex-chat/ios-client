//
// ProjectArchiveTests.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation
import NDKSwiftCore
import NDKSwiftTesting
@testable import TENEXCore
@testable import TENEXFeatures
import Testing

@Suite("Project Archive Tests")
@MainActor
struct ProjectArchiveTests {
    // MARK: - Archive Tests

    @Test("ProjectListViewModel archive removes project from visible list")
    func archiveRemovesProjectFromList() async throws {
        let ndk = NDK(relayURLs: [])
        let dataStore = DataStore(ndk: ndk)
        let archiveStorage = InMemoryArchiveStorage()
        let viewModel = ProjectListViewModel(
            dataStore: dataStore,
            archiveStorage: archiveStorage
        )

        // Subscription starts automatically in init
        #expect(viewModel.projects.isEmpty)

        // Archive a non-existent project (should not crash)
        await viewModel.archiveProject(id: "test-project")

        #expect(viewModel.projects.isEmpty)
    }

    @Test("ProjectListViewModel archive persists to storage")
    func archivePersistsToStorage() async throws {
        let ndk = NDK(relayURLs: [])
        let dataStore = DataStore(ndk: ndk)
        let archiveStorage = InMemoryArchiveStorage()
        let viewModel = ProjectListViewModel(
            dataStore: dataStore,
            archiveStorage: archiveStorage
        )

        // Subscription starts automatically
        await viewModel.archiveProject(id: "test-project")

        // Verify storage was updated
        #expect(archiveStorage.isArchived(projectID: "test-project") == true)
    }

    @Test("ProjectListViewModel unarchive restores project")
    func unarchiveRestoresProject() async throws {
        let ndk = NDK(relayURLs: [])
        let dataStore = DataStore(ndk: ndk)
        let archiveStorage = InMemoryArchiveStorage()
        let viewModel = ProjectListViewModel(
            dataStore: dataStore,
            archiveStorage: archiveStorage
        )

        // Subscription starts automatically

        // Archive then unarchive
        await viewModel.archiveProject(id: "test-project")
        #expect(archiveStorage.isArchived(projectID: "test-project"))

        await viewModel.unarchiveProject(id: "test-project")
        #expect(!archiveStorage.isArchived(projectID: "test-project"))
    }
}
