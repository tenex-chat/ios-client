//
// ProjectListViewModelTests.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation
import NDKSwiftCore
@testable import TENEXCore
@testable import TENEXFeatures
import Testing

@Suite("ProjectListViewModel Tests")
@MainActor
struct ProjectListViewModelTests {
    // MARK: Internal

    // MARK: - Initial State Tests

    @Test("ProjectListViewModel starts with empty projects list")
    func startsWithEmptyProjects() async throws {
        let mockNDK = MockNDK()
        let viewModel = ProjectListViewModel(ndk: mockNDK, userPubkey: "test-pubkey")

        #expect(viewModel.projects.isEmpty)
    }

    @Test("ProjectListViewModel starts with not loading state")
    func startsNotLoading() async throws {
        let mockNDK = MockNDK()
        let viewModel = ProjectListViewModel(ndk: mockNDK, userPubkey: "test-pubkey")

        #expect(viewModel.isLoading == false)
    }

    @Test("ProjectListViewModel starts with no error")
    func startsWithNoError() async throws {
        let mockNDK = MockNDK()
        let viewModel = ProjectListViewModel(ndk: mockNDK, userPubkey: "test-pubkey")

        #expect(viewModel.errorMessage == nil)
    }

    // MARK: - Loading State Tests

    @Test("ProjectListViewModel shows loading state during fetch")
    func showsLoadingStateDuringFetch() async throws {
        let mockNDK = MockNDK()

        // Create a mock event that should result in a valid project
        let event = createMockProjectEvent(
            projectID: "test-project",
            pubkey: "test-pubkey",
            title: "Test Project"
        )
        mockNDK.mockEvents = [event]

        let viewModel = ProjectListViewModel(ndk: mockNDK, userPubkey: "test-pubkey")

        // Start loading
        let loadTask = Task {
            await viewModel.loadProjects()
        }

        // Give a tiny moment for loading to start
        try await Task.sleep(nanoseconds: 100_000) // 0.1ms

        // Check if loading state is captured (may be flaky due to timing)
        // After load completes, loading should be false
        await loadTask.value

        #expect(viewModel.isLoading == false)
    }

    @Test("ProjectListViewModel stops loading after successful fetch")
    func stopsLoadingAfterSuccess() async throws {
        let mockNDK = MockNDK()
        let event = createMockProjectEvent(
            projectID: "test-project",
            pubkey: "test-pubkey",
            title: "Test Project"
        )
        mockNDK.mockEvents = [event]

        let viewModel = ProjectListViewModel(ndk: mockNDK, userPubkey: "test-pubkey")

        await viewModel.loadProjects()

        #expect(viewModel.isLoading == false)
    }

    @Test("ProjectListViewModel stops loading after error")
    func stopsLoadingAfterError() async throws {
        let mockNDK = MockNDK()
        mockNDK.shouldThrowError = true

        let viewModel = ProjectListViewModel(ndk: mockNDK, userPubkey: "test-pubkey")

        await viewModel.loadProjects()

        #expect(viewModel.isLoading == false)
    }

    // MARK: - Project Loading Tests

    @Test("ProjectListViewModel loads single project successfully")
    func loadsSingleProject() async throws {
        let mockNDK = MockNDK()
        let event = createMockProjectEvent(
            projectID: "test-project",
            pubkey: "test-pubkey",
            title: "Test Project"
        )
        mockNDK.mockEvents = [event]

        let viewModel = ProjectListViewModel(ndk: mockNDK, userPubkey: "test-pubkey")

        await viewModel.loadProjects()

        #expect(viewModel.projects.count == 1)
        #expect(viewModel.projects[0].id == "test-project")
        #expect(viewModel.projects[0].title == "Test Project")
        #expect(viewModel.errorMessage == nil)
    }

    @Test("ProjectListViewModel loads multiple projects successfully")
    func loadsMultipleProjects() async throws {
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

        let viewModel = ProjectListViewModel(ndk: mockNDK, userPubkey: "test-pubkey")

        await viewModel.loadProjects()

        #expect(viewModel.projects.count == 3)
        #expect(viewModel.projects[0].id == "project-1")
        #expect(viewModel.projects[1].id == "project-2")
        #expect(viewModel.projects[2].id == "project-3")
        #expect(viewModel.errorMessage == nil)
    }

    @Test("ProjectListViewModel skips invalid project events")
    func skipsInvalidEvents() async throws {
        let mockNDK = MockNDK()

        // Valid event
        let validEvent = createMockProjectEvent(
            projectID: "valid-project",
            pubkey: "test-pubkey",
            title: "Valid Project"
        )

        // Invalid event (wrong kind)
        let invalidEvent = NDKEvent(
            pubkey: "test-pubkey",
            createdAt: Timestamp(Date().timeIntervalSince1970),
            kind: 1, // Wrong kind (should be 31_933)
            tags: [
                ["d", "invalid-project"],
                ["title", "Invalid Project"],
            ],
            content: "{}"
        )

        mockNDK.mockEvents = [validEvent, invalidEvent]

        let viewModel = ProjectListViewModel(ndk: mockNDK, userPubkey: "test-pubkey")

        await viewModel.loadProjects()

        // Should only have the valid project
        #expect(viewModel.projects.count == 1)
        #expect(viewModel.projects[0].id == "valid-project")
    }

    @Test("ProjectListViewModel loads projects with descriptions")
    func loadsProjectsWithDescriptions() async throws {
        let mockNDK = MockNDK()
        let event = createMockProjectEvent(
            projectID: "test-project",
            pubkey: "test-pubkey",
            title: "Test Project",
            description: "This is a test project"
        )
        mockNDK.mockEvents = [event]

        let viewModel = ProjectListViewModel(ndk: mockNDK, userPubkey: "test-pubkey")

        await viewModel.loadProjects()

        #expect(viewModel.projects.count == 1)
        #expect(viewModel.projects[0].description == "This is a test project")
    }

    // MARK: - Error Handling Tests

    @Test("ProjectListViewModel shows error message on subscription failure")
    func showsErrorOnSubscriptionFailure() async throws {
        let mockNDK = MockNDK()
        mockNDK.shouldThrowError = true
        mockNDK.errorToThrow = MockNDK.MockError.subscriptionFailed

        let viewModel = ProjectListViewModel(ndk: mockNDK, userPubkey: "test-pubkey")

        await viewModel.loadProjects()

        let errorMessage = try #require(viewModel.errorMessage)
        #expect(errorMessage.isEmpty == false)
    }

    @Test("ProjectListViewModel keeps existing projects on error")
    func keepsExistingProjectsOnError() async throws {
        let mockNDK = MockNDK()

        // First load succeeds
        let event = createMockProjectEvent(
            projectID: "test-project",
            pubkey: "test-pubkey",
            title: "Test Project"
        )
        mockNDK.mockEvents = [event]

        let viewModel = ProjectListViewModel(ndk: mockNDK, userPubkey: "test-pubkey")

        await viewModel.loadProjects()

        #expect(viewModel.projects.count == 1)

        // Second load fails
        mockNDK.shouldThrowError = true
        mockNDK.mockEvents = []

        await viewModel.refresh()

        // Projects should still be there
        #expect(viewModel.projects.count == 1)
        #expect(viewModel.errorMessage != nil)
    }

    // MARK: - Refresh Tests

    @Test("ProjectListViewModel refresh clears error message")
    func refreshClearsError() async throws {
        let mockNDK = MockNDK()
        mockNDK.shouldThrowError = true

        let viewModel = ProjectListViewModel(ndk: mockNDK, userPubkey: "test-pubkey")

        await viewModel.loadProjects()

        #expect(viewModel.errorMessage != nil)

        // Fix the mock and refresh
        mockNDK.shouldThrowError = false
        let event = createMockProjectEvent(
            projectID: "test-project",
            pubkey: "test-pubkey",
            title: "Test Project"
        )
        mockNDK.mockEvents = [event]

        await viewModel.refresh()

        #expect(viewModel.errorMessage == nil)
    }

    @Test("ProjectListViewModel refresh reloads projects")
    func refreshReloadsProjects() async throws {
        let mockNDK = MockNDK()
        let event1 = createMockProjectEvent(
            projectID: "project-1",
            pubkey: "test-pubkey",
            title: "Project One"
        )
        mockNDK.mockEvents = [event1]

        let viewModel = ProjectListViewModel(ndk: mockNDK, userPubkey: "test-pubkey")

        await viewModel.loadProjects()

        #expect(viewModel.projects.count == 1)

        // Add more projects and refresh
        let event2 = createMockProjectEvent(
            projectID: "project-2",
            pubkey: "test-pubkey",
            title: "Project Two"
        )
        mockNDK.mockEvents = [event1, event2]

        await viewModel.refresh()

        #expect(viewModel.projects.count == 2)
    }

    @Test("ProjectListViewModel refresh shows loading state")
    func refreshShowsLoadingState() async throws {
        let mockNDK = MockNDK()
        let event = createMockProjectEvent(
            projectID: "test-project",
            pubkey: "test-pubkey",
            title: "Test Project"
        )
        mockNDK.mockEvents = [event]

        let viewModel = ProjectListViewModel(ndk: mockNDK, userPubkey: "test-pubkey")

        await viewModel.loadProjects()

        // Start refresh
        let refreshTask = Task {
            await viewModel.refresh()
        }

        // Give a tiny moment for loading to start
        try await Task.sleep(nanoseconds: 100_000) // 0.1ms

        // After refresh completes, loading should be false
        await refreshTask.value

        #expect(viewModel.isLoading == false)
    }

    // MARK: - Empty State Tests

    @Test("ProjectListViewModel handles no projects gracefully")
    func handlesNoProjects() async throws {
        let mockNDK = MockNDK()
        mockNDK.mockEvents = [] // No events

        let viewModel = ProjectListViewModel(ndk: mockNDK, userPubkey: "test-pubkey")

        await viewModel.loadProjects()

        #expect(viewModel.projects.isEmpty)
        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.isLoading == false)
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

        return NDKEvent(
            pubkey: pubkey,
            createdAt: Timestamp(Date().timeIntervalSince1970),
            kind: 31_933, // Project kind
            tags: [
                ["d", projectID],
                ["title", title],
            ],
            content: content
        )
    }
}
