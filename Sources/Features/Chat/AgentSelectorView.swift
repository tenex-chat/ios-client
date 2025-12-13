//
// AgentSelectorView.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import SwiftUI

// MARK: - AgentSelectorView

/// Agent selector sheet for choosing which agent to chat with
public struct AgentSelectorView: View {
    // MARK: Lifecycle

    /// Initialize the agent selector view
    /// - Parameter viewModel: The agent selector view model
    public init(viewModel: AgentSelectorViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    // MARK: Public

    public var body: some View {
        NavigationStack {
            List {
                ForEach(viewModel.availableAgents) { agent in
                    agentRow(agent)
                }
            }
            .navigationTitle("Select Agent")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        viewModel.dismissSelector()
                    }
                }
            }
        }
    }

    // MARK: Private

    @State private var viewModel: AgentSelectorViewModel

    private func agentRow(_ agent: AgentInfo) -> some View {
        Button {
            viewModel.selectAgent(agent.id)
            viewModel.dismissSelector()
        } label: {
            HStack(spacing: 12) {
                // Agent icon
                Image(systemName: agent.icon)
                    .font(.system(size: 24))
                    .foregroundStyle(.blue)
                    .frame(width: 36, height: 36)

                // Agent name
                Text(agent.name)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.primary)

                Spacer()

                // Selection indicator
                if viewModel.selectedAgentID == agent.id {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.blue)
                }
            }
            .padding(.vertical, 8)
        }
    }
}
