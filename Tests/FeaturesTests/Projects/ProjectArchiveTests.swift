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
    // MARK: Internal

    // MARK: - Archive Tests

    @Test("ProjectListViewModel archive removes project from visible list")
    func archiveRemovesProjectFromList() async throws {
        let mockNDK = MockNDK()
        let event = createMockProjectEvent(
            projectID: "test-project",
            pubkey: "test-pubkey",
            title: "Test Project"
        )
        mockNDK.mockEvents = [event]

        let archiveStorage = InMemoryArchiveStorage()
        let viewModel = ProjectListViewModel(
            ndk: mockNDK,
            userPubkey: "test-pubkey",
            archiveStorage: archiveStorage
        )

        await viewModel.loadProjects()
        #expect(viewModel.projects.count == 1)

        // Archive the project
        await viewModel.archiveProject(id: "test-project")

        // Project should no longer be visible
        #expect(viewModel.projects.isEmpty)
    }

    @Test("ProjectListViewModel archived projects are filtered on load")
    func archivedProjectsFilteredOnLoad() async throws {
        let mockNDK = MockNDK()
        let event1 = createMockProjectEvent(
            projectID: "project-1",
            pubkey: "test-pubkey",
            title: "Project One"
        )
        let event2 = createMockProjectEvent(
            projectID: "project-2",
            pubkey: "test-pubkey",
            title: "Project Two"
        )
        mockNDK.mockEvents = [event1, event2]

        // Pre-archive one project
        let archiveStorage = InMemoryArchiveStorage()
        archiveStorage.archive(projectID: "project-1")

        let viewModel = ProjectListViewModel(
            ndk: mockNDK,
            userPubkey: "test-pubkey",
            archiveStorage: archiveStorage
        )

        await viewModel.loadProjects()

        // Only non-archived project should be visible
        #expect(viewModel.projects.count == 1)
        #expect(viewModel.projects[0].id == "project-2")
    }

    @Test("ProjectListViewModel unarchive restores project to list")
    func unarchiveRestoresProject() async throws {
        let mockNDK = MockNDK()
        let event = createMockProjectEvent(
            projectID: "test-project",
            pubkey: "test-pubkey",
            title: "Test Project"
        )
        mockNDK.mockEvents = [event]

        let archiveStorage = InMemoryArchiveStorage()
        let viewModel = ProjectListViewModel(
            ndk: mockNDK,
            userPubkey: "test-pubkey",
            archiveStorage: archiveStorage
        )

        await viewModel.loadProjects()
        #expect(viewModel.projects.count == 1)

        // Archive then unarchive
        await viewModel.archiveProject(id: "test-project")
        #expect(viewModel.projects.isEmpty)

        await viewModel.unarchiveProject(id: "test-project")

        // Project should be visible again after reload
        await viewModel.loadProjects()
        #expect(viewModel.projects.count == 1)
    }

    @Test("ProjectListViewModel archive persists to storage")
    func archivePersistsToStorage() async throws {
        let mockNDK = MockNDK()
        let event = createMockProjectEvent(
            projectID: "test-project",
            pubkey: "test-pubkey",
            title: "Test Project"
        )
        mockNDK.mockEvents = [event]

        let archiveStorage = InMemoryArchiveStorage()
        let viewModel = ProjectListViewModel(
            ndk: mockNDK,
            userPubkey: "test-pubkey",
            archiveStorage: archiveStorage
        )

        await viewModel.loadProjects()
        await viewModel.archiveProject(id: "test-project")

        // Verify storage was updated
        #expect(archiveStorage.isArchived(projectID: "test-project") == true)
    }

    @Test("ProjectListViewModel archive multiple projects")
    func archiveMultipleProjects() async throws {
        let mockNDK = MockNDK()
        let event1 = createMockProjectEvent(
            projectID: "project-1",
            pubkey: "test-pubkey",
            title: "Project One"
        )
        let event2 = createMockProjectEvent(
            projectID: "project-2",
            pubkey: "test-pubkey",
            title: "Project Two"
        )
        let event3 = createMockProjectEvent(
            projectID: "project-3",
            pubkey: "test-pubkey",
            title: "Project Three"
        )
        mockNDK.mockEvents = [event1, event2, event3]

        let archiveStorage = InMemoryArchiveStorage()
        let viewModel = ProjectListViewModel(
            ndk: mockNDK,
            userPubkey: "test-pubkey",
            archiveStorage: archiveStorage
        )

        await viewModel.loadProjects()
        #expect(viewModel.projects.count == 3)

        // Archive two projects
        await viewModel.archiveProject(id: "project-1")
        await viewModel.archiveProject(id: "project-3")

        // Only project-2 should remain
        #expect(viewModel.projects.count == 1)
        #expect(viewModel.projects[0].id == "project-2")
    }

    // MARK: Private

    // MARK: - Helper Functions

    /// Create a mock project event for testing
    private func createMockProjectEvent(
        projectID: String,
        pubkey: String,
        title: String,
        description: String? = nil
    ) -> NDKEvent {
        let content = if let description {
            "{\"description\": \"\(description)\"}"
        } else {
            "{}"
        }

        return NDKEvent.test(
            kind: 31_933, // Project kind
            content: content,
            tags: [
                ["d", projectID],
                ["title", title],
            ],
            pubkey: pubkey
        )
    }
}
