//
// AgentSelectorView.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import SwiftUI
import TENEXCore

// MARK: - AgentSelectorView

/// Agent selector sheet for choosing which agent to chat with
/// Displays online agents from ProjectStatus (kind:24010)
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
                if viewModel.agents.isEmpty {
                    emptyState
                } else {
                    ForEach(viewModel.agents) { agent in
                        agentRow(agent)
                    }
                }
            }
            .navigationTitle("Select Agent")
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
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

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Agents Online", systemImage: "person.2.slash")
        } description: {
            Text("No agents are currently available for this project.")
        }
    }

    private func agentRow(_ agent: ProjectAgent) -> some View {
        Button {
            viewModel.selectAgent(agent.pubkey)
            viewModel.dismissSelector()
        } label: {
            HStack(spacing: 12) {
                // Agent avatar (placeholder - will use NDKUIProfilePicture when NDKSwiftUI bug is fixed)
                agentAvatar(for: agent)

                // Agent info
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(agent.name)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.primary)

                        if agent.isGlobal {
                            Text("Global")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.blue.opacity(0.8), in: Capsule())
                        }
                    }

                    if let model = agent.model {
                        Text(model)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                // Selection indicator
                if viewModel.selectedAgentPubkey == agent.pubkey {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.blue)
                }
            }
            .padding(.vertical, 8)
        }
    }

    private func agentAvatar(for agent: ProjectAgent) -> some View {
        let initial = agent.name.prefix(1).uppercased()
        return Text(initial)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 40, height: 40)
            .background(Color.blue.gradient, in: Circle())
    }
}

// MARK: - AgentSelectorButton

/// Compact button to show currently selected agent and open selector
public struct AgentSelectorButton: View {
    // MARK: Lifecycle

    public init(viewModel: AgentSelectorViewModel) {
        self.viewModel = viewModel
    }

    // MARK: Public

    public var body: some View {
        Button {
            viewModel.presentSelector()
        } label: {
            HStack(spacing: 8) {
                if let agent = viewModel.selectedAgent {
                    // Show selected agent with profile picture
                    agentAvatar(for: agent)

                    Text(agent.name)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.primary)
                } else {
                    // No agent selected
                    Image(systemName: "person.circle")
                        .font(.system(size: 20))
                        .foregroundStyle(.secondary)

                    Text("Select Agent")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }

                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial, in: Capsule())
        }
        .sheet(isPresented: Binding(
            get: { viewModel.isPresented },
            set: { viewModel.isPresented = $0 }
        )) {
            AgentSelectorView(viewModel: viewModel)
        }
    }

    // MARK: Private

    @Bindable private var viewModel: AgentSelectorViewModel

    private func agentAvatar(for agent: ProjectAgent) -> some View {
        Text(agent.name.prefix(1).uppercased())
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 24, height: 24)
            .background(Color.blue.gradient, in: Circle())
    }
}
