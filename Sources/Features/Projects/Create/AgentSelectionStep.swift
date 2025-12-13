//
// AgentSelectionStep.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import SwiftUI

struct AgentSelectionStep: View {
    @ObservedObject var viewModel: CreateProjectViewModel

    var body: some View {
        VStack {
            if viewModel.isLoadingAgents {
                ProgressView("Loading agents...")
            } else if viewModel.availableAgents.isEmpty {
                ContentUnavailableView("No Agents Found", systemImage: "person.slash", description: Text("No agent definitions found."))
            } else {
                List {
                    ForEach(viewModel.availableAgents) { agent in
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

                            if viewModel.selectedAgentIds.contains(agent.id) {
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
                }
            }
        }
    }

    private func toggleSelection(for id: String) {
        if viewModel.selectedAgentIds.contains(id) {
            viewModel.selectedAgentIds.remove(id)
        } else {
            viewModel.selectedAgentIds.insert(id)
        }
    }
}
