//
// AgentSelectorViewModelTests.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation
@testable import TENEXFeatures
import Testing

@Suite("AgentSelectorViewModel Tests")
@MainActor
struct AgentSelectorViewModelTests {
    @Test("Initialize with no agents")
    func initializeWithNoAgents() {
        // Given/When: Creating view model with empty agents
        let viewModel = AgentSelectorViewModel(availableAgents: [])

        // Then: View model has no agents and no selection
        #expect(viewModel.availableAgents.isEmpty)
        #expect(viewModel.selectedAgentID == nil)
        #expect(viewModel.isPresented == false)
    }

    @Test("Initialize with available agents")
    func initializeWithAgents() {
        // Given: List of agents
        let agents = [
            AgentInfo(id: "agent-1", name: "Assistant", icon: "person.fill"),
            AgentInfo(id: "agent-2", name: "Code Helper", icon: "chevron.left.forwardslash.chevron.right"),
        ]

        // When: Creating view model
        let viewModel = AgentSelectorViewModel(availableAgents: agents)

        // Then: View model has agents
        #expect(viewModel.availableAgents.count == 2)
        #expect(viewModel.selectedAgentID == nil)
    }

    @Test("Select agent")
    func selectAgent() {
        // Given: View model with agents
        let agents = [
            AgentInfo(id: "agent-1", name: "Assistant", icon: "person.fill"),
            AgentInfo(id: "agent-2", name: "Code Helper", icon: "chevron.left.forwardslash.chevron.right"),
        ]
        let viewModel = AgentSelectorViewModel(availableAgents: agents)

        // When: Selecting agent
        viewModel.selectAgent("agent-1")

        // Then: Agent is selected
        #expect(viewModel.selectedAgentID == "agent-1")
    }

    @Test("Change agent selection")
    func changeAgentSelection() {
        // Given: View model with selected agent
        let agents = [
            AgentInfo(id: "agent-1", name: "Assistant", icon: "person.fill"),
            AgentInfo(id: "agent-2", name: "Code Helper", icon: "chevron.left.forwardslash.chevron.right"),
        ]
        let viewModel = AgentSelectorViewModel(availableAgents: agents)
        viewModel.selectAgent("agent-1")

        // When: Changing selection
        viewModel.selectAgent("agent-2")

        // Then: New agent is selected
        #expect(viewModel.selectedAgentID == "agent-2")
    }

    @Test("Get selected agent info")
    func getSelectedAgentInfo() {
        // Given: View model with selected agent
        let agents = [
            AgentInfo(id: "agent-1", name: "Assistant", icon: "person.fill"),
            AgentInfo(id: "agent-2", name: "Code Helper", icon: "chevron.left.forwardslash.chevron.right"),
        ]
        let viewModel = AgentSelectorViewModel(availableAgents: agents)
        viewModel.selectAgent("agent-1")

        // When: Getting selected agent info
        let selectedAgent = viewModel.selectedAgent

        // Then: Correct agent info is returned
        #expect(selectedAgent?.id == "agent-1")
        #expect(selectedAgent?.name == "Assistant")
        #expect(selectedAgent?.icon == "person.fill")
    }

    @Test("Selected agent is nil when no selection")
    func selectedAgentNilWhenNoSelection() {
        // Given: View model without selection
        let agents = [
            AgentInfo(id: "agent-1", name: "Assistant", icon: "person.fill"),
        ]
        let viewModel = AgentSelectorViewModel(availableAgents: agents)

        // When: Getting selected agent
        let selectedAgent = viewModel.selectedAgent

        // Then: Selected agent is nil
        #expect(selectedAgent == nil)
    }

    @Test("Present agent selector sheet")
    func presentAgentSelector() {
        // Given: View model
        let viewModel = AgentSelectorViewModel(availableAgents: [])
        #expect(viewModel.isPresented == false)

        // When: Presenting selector
        viewModel.presentSelector()

        // Then: Selector is presented
        #expect(viewModel.isPresented == true)
    }

    @Test("Dismiss agent selector sheet")
    func dismissAgentSelector() {
        // Given: View model with presented selector
        let viewModel = AgentSelectorViewModel(availableAgents: [])
        viewModel.presentSelector()
        #expect(viewModel.isPresented == true)

        // When: Dismissing selector
        viewModel.dismissSelector()

        // Then: Selector is dismissed
        #expect(viewModel.isPresented == false)
    }
}
