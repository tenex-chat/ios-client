//
// AgentSelectorViewModelTests.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation
import TENEXCore
@testable import TENEXFeatures
import Testing

@Suite("AgentSelectorViewModel Tests")
@MainActor
struct AgentSelectorViewModelTests {
    @Test("Initialize with no agents")
    func initializeWithNoAgents() {
        // Given/When: Creating view model with empty agents
        let viewModel = AgentSelectorViewModel(agents: [])

        // Then: View model has no agents and no selection
        #expect(viewModel.agents.isEmpty)
        #expect(viewModel.selectedAgentPubkey == nil)
        #expect(viewModel.isPresented == false)
    }

    @Test("Initialize with agents auto-selects first")
    func initializeWithAgents() {
        // Given: List of agents (alphabetically ordered, no PM)
        let agents = [
            ProjectAgent(pubkey: "abc123", name: "Claude", isGlobal: false),
            ProjectAgent(pubkey: "def456", name: "GPT-4", isGlobal: false),
        ]

        // When: Creating view model
        let viewModel = AgentSelectorViewModel(agents: agents)

        // Then: View model has agents sorted alphabetically and first is auto-selected
        #expect(viewModel.agents.count == 2)
        #expect(viewModel.agents[0].name == "Claude") // Alphabetically first
        #expect(viewModel.agents[1].name == "GPT-4")
        #expect(viewModel.selectedAgentPubkey == "abc123")
    }

    @Test("Agents are sorted PM first then alphabetically")
    func agentsAreSortedPMFirstThenAlphabetically() {
        // Given: List of agents with PM not first
        let agents = [
            ProjectAgent(pubkey: "def456", name: "Zulu", isGlobal: false, isPM: false),
            ProjectAgent(pubkey: "ghi789", name: "Alpha", isGlobal: false, isPM: false),
            ProjectAgent(pubkey: "abc123", name: "PM Agent", isGlobal: false, isPM: true),
            ProjectAgent(pubkey: "jkl012", name: "Beta", isGlobal: false, isPM: false),
        ]

        // When: Creating view model
        let viewModel = AgentSelectorViewModel(agents: agents)

        // Then: PM is first, rest are alphabetically sorted
        #expect(viewModel.agents.count == 4)
        #expect(viewModel.agents[0].name == "PM Agent") // PM first
        #expect(viewModel.agents[0].isPM == true)
        #expect(viewModel.agents[1].name == "Alpha") // Then alphabetical
        #expect(viewModel.agents[2].name == "Beta")
        #expect(viewModel.agents[3].name == "Zulu")
    }

    @Test("Initialize with default agent pubkey")
    func initializeWithDefaultAgent() {
        // Given: List of agents
        let agents = [
            ProjectAgent(pubkey: "abc123", name: "Claude", isGlobal: false),
            ProjectAgent(pubkey: "def456", name: "GPT-4", isGlobal: false),
        ]

        // When: Creating view model with specific default
        let viewModel = AgentSelectorViewModel(agents: agents, defaultAgentPubkey: "def456")

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
        let viewModel = AgentSelectorViewModel(agents: agents)

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
        let viewModel = AgentSelectorViewModel(agents: agents)
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
        let viewModel = AgentSelectorViewModel(agents: agents)
        viewModel.selectAgent("abc123")

        // When: Getting selected agent
        let selectedAgent = viewModel.selectedAgent

        // Then: Correct agent is returned
        #expect(selectedAgent?.pubkey == "abc123")
        #expect(selectedAgent?.name == "Claude")
        #expect(selectedAgent?.isGlobal == true)
        #expect(selectedAgent?.model == "claude-sonnet-4")
    }

    @Test("Update agents clears invalid selection")
    func updateAgentsClearsInvalidSelection() {
        // Given: View model with selected agent
        let agents = [
            ProjectAgent(pubkey: "abc123", name: "Claude", isGlobal: false),
            ProjectAgent(pubkey: "def456", name: "GPT-4", isGlobal: false),
        ]
        let viewModel = AgentSelectorViewModel(agents: agents)
        viewModel.selectAgent("def456")

        // When: Updating agents without the selected one
        let newAgents = [
            ProjectAgent(pubkey: "abc123", name: "Claude", isGlobal: false),
            ProjectAgent(pubkey: "ghi789", name: "Gemini", isGlobal: false),
        ]
        viewModel.updateAgents(newAgents)

        // Then: Selection falls back to first agent (alphabetically)
        #expect(viewModel.selectedAgentPubkey == "abc123")
        #expect(viewModel.agents[0].name == "Claude") // Alphabetically first
        #expect(viewModel.agents[1].name == "Gemini")
    }

    @Test("Update agents maintains sorting")
    func updateAgentsMaintainsSorting() {
        // Given: View model with agents
        let agents = [
            ProjectAgent(pubkey: "abc123", name: "Zulu", isGlobal: false, isPM: false),
        ]
        let viewModel = AgentSelectorViewModel(agents: agents)

        // When: Updating with unsorted agents including PM
        let newAgents = [
            ProjectAgent(pubkey: "def456", name: "Zulu", isGlobal: false, isPM: false),
            ProjectAgent(pubkey: "ghi789", name: "Alpha", isGlobal: false, isPM: false),
            ProjectAgent(pubkey: "jkl012", name: "PM Agent", isGlobal: false, isPM: true),
        ]
        viewModel.updateAgents(newAgents)

        // Then: Agents are sorted PM first, then alphabetically
        #expect(viewModel.agents.count == 3)
        #expect(viewModel.agents[0].name == "PM Agent") // PM first
        #expect(viewModel.agents[1].name == "Alpha") // Then alphabetical
        #expect(viewModel.agents[2].name == "Zulu")
    }

    @Test("Update agents keeps valid selection")
    func updateAgentsKeepsValidSelection() {
        // Given: View model with selected agent
        let agents = [
            ProjectAgent(pubkey: "abc123", name: "Claude", isGlobal: false),
            ProjectAgent(pubkey: "def456", name: "GPT-4", isGlobal: false),
        ]
        let viewModel = AgentSelectorViewModel(agents: agents)
        viewModel.selectAgent("def456")

        // When: Updating agents keeping the selected one
        let newAgents = [
            ProjectAgent(pubkey: "abc123", name: "Claude", isGlobal: false),
            ProjectAgent(pubkey: "def456", name: "GPT-4", isGlobal: false, model: "gpt-4-turbo"),
        ]
        viewModel.updateAgents(newAgents)

        // Then: Selection is preserved
        #expect(viewModel.selectedAgentPubkey == "def456")
        #expect(viewModel.selectedAgent?.model == "gpt-4-turbo")
    }

    @Test("Present agent selector sheet")
    func presentAgentSelector() {
        // Given: View model
        let viewModel = AgentSelectorViewModel(agents: [])
        #expect(viewModel.isPresented == false)

        // When: Presenting selector
        viewModel.presentSelector()

        // Then: Selector is presented
        #expect(viewModel.isPresented == true)
    }

    @Test("Dismiss agent selector sheet")
    func dismissAgentSelector() {
        // Given: View model with presented selector
        let viewModel = AgentSelectorViewModel(agents: [])
        viewModel.presentSelector()
        #expect(viewModel.isPresented == true)

        // When: Dismissing selector
        viewModel.dismissSelector()

        // Then: Selector is dismissed
        #expect(viewModel.isPresented == false)
    }
}
