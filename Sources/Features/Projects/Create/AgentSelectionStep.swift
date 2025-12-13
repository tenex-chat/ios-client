//
// AgentSelectionStep.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import SwiftUI
import TENEXCore

struct AgentSelectionStep: View {
    // MARK: Internal

    @Bindable var viewModel: CreateProjectViewModel

    var body: some View {
        VStack {
            if viewModel.isLoadingAgents {
                ProgressView("Loading agents...")
            } else if viewModel.availableAgents.isEmpty {
                emptyView
            } else {
                agentList
            }
        }
    }

    // MARK: Private

    private var emptyView: some View {
        ContentUnavailableView(
            "No Agents Found",
            systemImage: "person.slash",
            description: Text("No agent definitions found.")
        )
    }

    private var agentList: some View {
        List {
            ForEach(viewModel.availableAgents) { agent in
                agentRow(for: agent)
            }
        }
    }

    private func agentRow(for agent: AgentDefinition) -> some View {
        HStack {
            VStack(alignment: .leading) {
                Text(agent.name)
                    .font(.headline)
                Text(agent.description ?? "No description")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            if viewModel.selectedAgentIDs.contains(agent.id) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.accentColor)
            } else {
                Image(systemName: "circle")
                    .foregroundColor(.secondary)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            toggleSelection(for: agent.id)
        }
    }

    private func toggleSelection(for id: String) {
        if viewModel.selectedAgentIDs.contains(id) {
            viewModel.selectedAgentIDs.remove(id)
        } else {
            viewModel.selectedAgentIDs.insert(id)
        }
    }
}
