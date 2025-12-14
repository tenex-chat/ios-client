//
// AgentSelectorViewModelTests.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation
import NDKSwiftCore
import TENEXCore
@testable import TENEXFeatures
import Testing

@Suite("AgentSelectorViewModel Tests")
@MainActor
struct AgentSelectorViewModelTests {
    // MARK: Internal

    @Test("Initialize with no agents")
    func initializeWithNoAgents() {
        // Given/When: Creating view model with empty data store
        let dataStore = makeDataStore(withAgents: [])
        let viewModel = AgentSelectorViewModel(
            dataStore: dataStore,
            projectReference: testProjectRef
        )

        // Then: View model has no agents and no selection
        #expect(viewModel.agents.isEmpty)
        #expect(viewModel.selectedAgentPubkey == nil)
        #expect(viewModel.isPresented == false)
    }

    @Test("Initialize with agents auto-selects first")
    func initializeWithAgents() {
        // Given: List of agents
        let agents = [
            ProjectAgent(pubkey: "abc123", name: "Claude", isGlobal: false),
            ProjectAgent(pubkey: "def456", name: "GPT-4", isGlobal: false),
        ]
        let dataStore = makeDataStore(withAgents: agents)

        // When: Creating view model
        let viewModel = AgentSelectorViewModel(
            dataStore: dataStore,
            projectReference: testProjectRef
        )

        // Then: View model has agents and first is auto-selected
        #expect(viewModel.agents.count == 2)
        #expect(viewModel.selectedAgentPubkey == "abc123")
    }

    @Test("Initialize with default agent pubkey")
    func initializeWithDefaultAgent() {
        // Given: List of agents
        let agents = [
            ProjectAgent(pubkey: "abc123", name: "Claude", isGlobal: false),
            ProjectAgent(pubkey: "def456", name: "GPT-4", isGlobal: false),
        ]
        let dataStore = makeDataStore(withAgents: agents)

        // When: Creating view model with specific default
        let viewModel = AgentSelectorViewModel(
            dataStore: dataStore,
            projectReference: testProjectRef,
            defaultAgentPubkey: "def456"
        )

        // Then: Specified agent is selected
        #expect(viewModel.selectedAgentPubkey == "def456")
    }

    @Test("Select agent")
    func selectAgent() {
        // Given: View model with agents
        let agents = [
            ProjectAgent(pubkey: "abc123", name: "Claude", isGlobal: false),
            ProjectAgent(pubkey: "def456", name: "GPT-4", isGlobal: false),
        ]
        let dataStore = makeDataStore(withAgents: agents)
        let viewModel = AgentSelectorViewModel(
            dataStore: dataStore,
            projectReference: testProjectRef
        )

        // When: Selecting agent
        viewModel.selectAgent("def456")

        // Then: Agent is selected
        #expect(viewModel.selectedAgentPubkey == "def456")
    }

    @Test("Change agent selection")
    func changeAgentSelection() {
        // Given: View model with selected agent
        let agents = [
            ProjectAgent(pubkey: "abc123", name: "Claude", isGlobal: false),
            ProjectAgent(pubkey: "def456", name: "GPT-4", isGlobal: false),
        ]
        let dataStore = makeDataStore(withAgents: agents)
        let viewModel = AgentSelectorViewModel(
            dataStore: dataStore,
            projectReference: testProjectRef
        )
        viewModel.selectAgent("abc123")

        // When: Changing selection
        viewModel.selectAgent("def456")

        // Then: New agent is selected
        #expect(viewModel.selectedAgentPubkey == "def456")
    }

    @Test("Get selected agent")
    func getSelectedAgent() {
        // Given: View model with selected agent
        let agents = [
            ProjectAgent(pubkey: "abc123", name: "Claude", isGlobal: true, model: "claude-sonnet-4"),
            ProjectAgent(pubkey: "def456", name: "GPT-4", isGlobal: false),
        ]
        let dataStore = makeDataStore(withAgents: agents)
        let viewModel = AgentSelectorViewModel(
            dataStore: dataStore,
            projectReference: testProjectRef
        )
        viewModel.selectAgent("abc123")

        // When: Getting selected agent
        let selectedAgent = viewModel.selectedAgent

        // Then: Correct agent is returned
        #expect(selectedAgent?.pubkey == "abc123")
        #expect(selectedAgent?.name == "Claude")
        #expect(selectedAgent?.isGlobal == true)
        #expect(selectedAgent?.model == "claude-sonnet-4")
    }

    @Test("Agents reactively update from data store")
    func agentsReactivelyUpdate() {
        // Given: View model with initial agents
        let initialAgents = [
            ProjectAgent(pubkey: "abc123", name: "Claude", isGlobal: false),
        ]
        let dataStore = makeDataStore(withAgents: initialAgents)
        let viewModel = AgentSelectorViewModel(
            dataStore: dataStore,
            projectReference: testProjectRef
        )
        #expect(viewModel.agents.count == 1)

        // When: Updating project status in data store
        let updatedAgents = [
            ProjectAgent(pubkey: "abc123", name: "Claude", isGlobal: false),
            ProjectAgent(pubkey: "def456", name: "GPT-4", isGlobal: false),
        ]
        let newStatus = ProjectStatus(
            projectCoordinate: testProjectRef,
            pubkey: "backendpubkey",
            agents: updatedAgents,
            createdAt: Date()
        )
        dataStore.setProjectStatus(newStatus, for: testProjectRef)

        // Then: Agents are automatically updated
        #expect(viewModel.agents.count == 2)
    }

    @Test("Present agent selector sheet")
    func presentAgentSelector() {
        // Given: View model
        let dataStore = makeDataStore(withAgents: [])
        let viewModel = AgentSelectorViewModel(
            dataStore: dataStore,
            projectReference: testProjectRef
        )
        #expect(viewModel.isPresented == false)

        // When: Presenting selector
        viewModel.presentSelector()

        // Then: Selector is presented
        #expect(viewModel.isPresented == true)
    }

    @Test("Dismiss agent selector sheet")
    func dismissAgentSelector() {
        // Given: View model with presented selector
        let dataStore = makeDataStore(withAgents: [])
        let viewModel = AgentSelectorViewModel(
            dataStore: dataStore,
            projectReference: testProjectRef
        )
        viewModel.presentSelector()
        #expect(viewModel.isPresented == true)

        // When: Dismissing selector
        viewModel.dismissSelector()

        // Then: Selector is dismissed
        #expect(viewModel.isPresented == false)
    }

    // MARK: Private

    private let testProjectRef = "31933:testpubkey:testproject"
    private let testNDK = NDK(relayURLs: [])

    private func makeDataStore(withAgents agents: [ProjectAgent]) -> DataStore {
        let dataStore = DataStore(ndk: testNDK)
        if !agents.isEmpty {
            let status = ProjectStatus(
                projectCoordinate: testProjectRef,
                pubkey: "backendpubkey",
                agents: agents,
                createdAt: Date()
            )
            dataStore.setProjectStatus(status, for: testProjectRef)
        }
        return dataStore
    }
}
