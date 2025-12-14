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
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    // MARK: Private

    @State private var viewModel: AgentSelectorViewModel

    private var avatarGradient: LinearGradient {
        LinearGradient(
            colors: [.blue, .purple],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Agents Online", systemImage: "sparkles")
        } description: {
            Text("No agents are currently available for this project.")
        }
    }

    private var globalBadge: some View {
        Text("Global")
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(.blue.gradient, in: Capsule())
    }

    private func agentRow(_ agent: ProjectAgent) -> some View {
        Button {
            viewModel.selectAgent(agent.pubkey)
            viewModel.dismissSelector()
        } label: {
            agentRowContent(agent)
        }
        .buttonStyle(.plain)
    }

    private func agentRowContent(_ agent: ProjectAgent) -> some View {
        HStack(spacing: 12) {
            agentAvatar(for: agent)
            agentInfo(agent)
            Spacer()
            selectionIndicator(for: agent)
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }

    private func agentInfo(_ agent: ProjectAgent) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Text(agent.name)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.primary)
                if agent.isGlobal {
                    globalBadge
                }
            }
            if let model = agent.model {
                Text(model)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func selectionIndicator(for agent: ProjectAgent) -> some View {
        if viewModel.selectedAgentPubkey == agent.pubkey {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 22))
                .foregroundStyle(.blue)
        }
    }

    private func agentAvatar(for agent: ProjectAgent) -> some View {
        Text(agent.name.prefix(1).uppercased())
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 40, height: 40)
            .background(avatarGradient, in: Circle())
    }
}

// MARK: - AgentSelectorButton

/// Compact chip button to show currently selected agent and open selector
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
            buttonContent
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $viewModel.isPresented) {
            AgentSelectorView(viewModel: viewModel)
        }
    }

    // MARK: Private

    @Bindable private var viewModel: AgentSelectorViewModel

    private var avatarGradient: LinearGradient {
        LinearGradient(
            colors: [.blue, .purple],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var buttonContent: some View {
        HStack(spacing: 6) {
            buttonIcon
            chevron
        }
        .padding(.leading, 8)
        .padding(.trailing, 10)
        .padding(.vertical, 6)
        .background(chipBackground)
        .overlay(chipBorder)
    }

    @ViewBuilder private var buttonIcon: some View {
        if let agent = viewModel.selectedAgent {
            agentAvatar(for: agent)
            Text(agent.name)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.primary)
        } else {
            Image(systemName: "sparkles")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
            Text("Agent")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }

    private var chevron: some View {
        Image(systemName: "chevron.up.chevron.down")
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(.tertiary)
    }

    private var chipBackground: some View {
        Capsule()
            .fill(.ultraThinMaterial)
    }

    private var chipBorder: some View {
        Capsule()
            .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
    }

    private func agentAvatar(for agent: ProjectAgent) -> some View {
        Text(agent.name.prefix(1).uppercased())
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 20, height: 20)
            .background(avatarGradient, in: Circle())
    }
}
