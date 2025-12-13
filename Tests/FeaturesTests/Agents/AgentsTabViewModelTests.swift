//
// AgentsTabViewModelTests.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation
import NDKSwiftCore
import NDKSwiftTesting
import TENEXCore
@testable import TENEXFeatures
import Testing

@Suite("AgentsTabViewModel Tests")
@MainActor
struct AgentsTabViewModelTests {
    @Test("Starts with empty agents list and not subscribed")
    func startsEmpty() {
        // Given/When
        let mockNDK = MockNDK()
        let viewModel = AgentsTabViewModel(ndk: mockNDK, projectID: "test-project")

        // Then
        #expect(viewModel.agents.isEmpty)
        #expect(viewModel.isLoading == false)
        #expect(viewModel.isSubscribed == false)
        #expect(viewModel.errorMessage == nil)
    }

    @Test("Subscribes and receives agents from ProjectStatus")
    func subscribesAndReceivesAgents() async {
        // Given: Mock NDK that returns a ProjectStatus event
        let mockNDK = MockNDK()
        let statusEvent = NDKEvent.test(
            kind: 24_010,
            content: "",
            tags: [
                ["d", "test-project"],
                ["agent", "abc123", "Claude", "global"],
                ["agent", "def456", "GPT-4"],
                ["model", "claude-sonnet-4", "Claude"],
            ],
            pubkey: "server"
        )
        mockNDK.mockEvents = [statusEvent]

        let viewModel = AgentsTabViewModel(ndk: mockNDK, projectID: "test-project")

        // When
        await viewModel.subscribe()

        // Then
        #expect(viewModel.agents.count == 2)
        #expect(viewModel.isLoading == false)
        #expect(viewModel.errorMessage == nil)

        let claude = viewModel.agents.first { $0.name == "Claude" }
        #expect(claude?.pubkey == "abc123")
        #expect(claude?.isGlobal == true)
        #expect(claude?.model == "claude-sonnet-4")
    }

    @Test("Updates agents in real-time as events arrive")
    func updatesAgentsInRealTime() async {
        // Given: Mock NDK that returns multiple ProjectStatus events
        let mockNDK = MockNDK()

        // First event: one agent
        let firstEvent = NDKEvent.test(
            kind: 24_010,
            content: "",
            tags: [
                ["d", "test-project"],
                ["agent", "abc123", "Claude"],
            ],
            pubkey: "server"
        )

        // Second event: two agents (real-time update)
        let secondEvent = NDKEvent.test(
            kind: 24_010,
            content: "",
            tags: [
                ["d", "test-project"],
                ["agent", "abc123", "Claude"],
                ["agent", "def456", "GPT-4"],
            ],
            pubkey: "server"
        )

        mockNDK.mockEvents = [firstEvent, secondEvent]

        let viewModel = AgentsTabViewModel(ndk: mockNDK, projectID: "test-project")

        // When: Subscribe to events
        await viewModel.subscribe()

        // Then: Should have the latest agents from the last event
        #expect(viewModel.agents.count == 2)
    }

    @Test("Handles empty ProjectStatus")
    func handlesEmptyStatus() async {
        // Given: Mock NDK that returns ProjectStatus with no agents
        let mockNDK = MockNDK()
        let statusEvent = NDKEvent.test(
            kind: 24_010,
            content: "",
            tags: [
                ["d", "test-project"],
            ],
            pubkey: "server"
        )
        mockNDK.mockEvents = [statusEvent]

        let viewModel = AgentsTabViewModel(ndk: mockNDK, projectID: "test-project")

        // When
        await viewModel.subscribe()

        // Then
        #expect(viewModel.agents.isEmpty)
        #expect(viewModel.isLoading == false)
    }

    @Test("Refresh clears agents and resubscribes")
    func refreshClearsAndResubscribes() async {
        // Given: View model with subscribed agents
        let mockNDK = MockNDK()
        let statusEvent = NDKEvent.test(
            kind: 24_010,
            content: "",
            tags: [
                ["d", "test-project"],
                ["agent", "abc123", "Claude"],
            ],
            pubkey: "server"
        )
        mockNDK.mockEvents = [statusEvent]

        let viewModel = AgentsTabViewModel(ndk: mockNDK, projectID: "test-project")
        await viewModel.subscribe()
        #expect(viewModel.agents.count == 1)

        // When: Refreshing with new data
        let newStatusEvent = NDKEvent.test(
            kind: 24_010,
            content: "",
            tags: [
                ["d", "test-project"],
                ["agent", "abc123", "Claude"],
                ["agent", "def456", "GPT-4"],
            ],
            pubkey: "server"
        )
        mockNDK.mockEvents = [newStatusEvent]

        await viewModel.refresh()

        // Then: Agents list is updated
        #expect(viewModel.agents.count == 2)
    }
}
