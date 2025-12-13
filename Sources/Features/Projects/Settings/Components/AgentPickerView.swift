//
// AgentPickerView.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import SwiftUI
import TENEXCore

// MARK: - AgentPickerView

/// Sheet for selecting agents from available list
struct AgentPickerView: View {
    // MARK: Lifecycle

    init(selectedAgentIDs: Binding<Set<String>>, availableAgents: Binding<[AgentDefinition]>) {
        _selectedAgentIDs = selectedAgentIDs
        _availableAgents = availableAgents
    }

    // MARK: Internal

    var body: some View {
        List {
            agentsListContent
        }
        .navigationTitle("Select Agents")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") {
                    dismiss()
                }
            }
        }
    }

    // MARK: Private

    @Environment(\.dismiss) private var dismiss
    @Binding private var selectedAgentIDs: Set<String>
    @Binding private var availableAgents: [AgentDefinition]

    @ViewBuilder private var agentsListContent: some View {
        if availableAgents.isEmpty {
            ContentUnavailableView(
                "No Agents Available",
                systemImage: "person.2.slash",
                description: Text("Create agents to add them to your project")
            )
        } else {
            ForEach(availableAgents) { agent in
                Button {
                    toggleAgent(agent.id)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(agent.title)
                                .font(.body)
                                .foregroundStyle(.primary)

                            if let role = agent.role {
                                Text(role)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Spacer()

                        if selectedAgentIDs.contains(agent.id) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.blue)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func toggleAgent(_ agentID: String) {
        if selectedAgentIDs.contains(agentID) {
            selectedAgentIDs.remove(agentID)
        } else {
            selectedAgentIDs.insert(agentID)
        }
    }
}
