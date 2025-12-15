//
// AgentSelectorView.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import NDKSwiftUI
import SwiftUI
import TENEXCore

// MARK: - AgentSelectorView

/// Agent selector sheet for choosing which agent to chat with
/// Displays online agents from ProjectStatus (kind:24010)
public struct AgentSelectorView: View {
    // MARK: Lifecycle

    /// Initialize the agent selector view
    /// - Parameters:
    ///   - viewModel: The agent selector view model
    ///   - onSettings: Optional callback when settings button is tapped for an agent
    public init(viewModel: AgentSelectorViewModel, onSettings: ((ProjectAgent) -> Void)? = nil) {
        _viewModel = State(initialValue: viewModel)
        self.onSettings = onSettings
    }

    // MARK: Public

    public var body: some View {
        NavigationStack {
            List {
                if self.viewModel.agents.isEmpty {
                    self.emptyState
                } else {
                    ForEach(self.viewModel.agents) { agent in
                        self.agentRow(agent)
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
                            self.viewModel.dismissSelector()
                        }
                    }
                }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    // MARK: Private

    @Environment(\.ndk) private var ndk
    @State private var viewModel: AgentSelectorViewModel

    private let onSettings: ((ProjectAgent) -> Void)?

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Agents Online", systemImage: "sparkles")
        } description: {
            Text("No agents are currently available for this project.")
        }
    }

    private var globalBadge: some View {
        Text("Global")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(.blue.gradient, in: Capsule())
    }

    private func agentRow(_ agent: ProjectAgent) -> some View {
        HStack(spacing: 12) {
            Button {
                self.viewModel.selectAgent(agent.pubkey)
                self.viewModel.dismissSelector()
            } label: {
                self.agentRowContent(agent)
            }
            .buttonStyle(.plain)

            if let onSettings {
                Button {
                    onSettings(agent)
                } label: {
                    Image(systemName: "gear")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func agentRowContent(_ agent: ProjectAgent) -> some View {
        HStack(spacing: 12) {
            self.agentAvatar(for: agent)
            self.agentInfo(agent)
            Spacer()
            self.selectionIndicator(for: agent)
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }

    private func agentInfo(_ agent: ProjectAgent) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Text(agent.name)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.primary)
                if agent.isGlobal {
                    self.globalBadge
                }
            }
            if let model = agent.model {
                Text(model)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func selectionIndicator(for agent: ProjectAgent) -> some View {
        if self.viewModel.selectedAgentPubkey == agent.pubkey {
            Image(systemName: "checkmark.circle.fill")
                .font(.title2)
                .foregroundStyle(.blue)
        }
    }

    @ViewBuilder
    private func agentAvatar(for agent: ProjectAgent) -> some View {
        if let ndk {
            NDKUIProfilePicture(ndk: ndk, pubkey: agent.pubkey, size: 40)
        } else {
            // Fallback when NDK is not available
            Circle()
                .fill(Color.gray.opacity(0.2))
                .frame(width: 40, height: 40)
                .overlay {
                    Text(agent.name.prefix(1).uppercased())
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.secondary)
                }
        }
    }
}

// MARK: - AgentSelectorButton

/// Compact chip button to show currently selected agent and open selector
public struct AgentSelectorButton: View {
    // MARK: Lifecycle

    public init(viewModel: AgentSelectorViewModel, onSettings: ((ProjectAgent) -> Void)? = nil) {
        self.viewModel = viewModel
        self.onSettings = onSettings
    }

    // MARK: Public

    public var body: some View {
        Button {
            self.viewModel.presentSelector()
        } label: {
            self.buttonContent
        }
        .buttonStyle(.plain)
        .sheet(isPresented: self.$viewModel.isPresented) {
            AgentSelectorView(viewModel: self.viewModel, onSettings: self.onSettings)
        }
    }

    // MARK: Private

    @Environment(\.ndk) private var ndk

    @Bindable private var viewModel: AgentSelectorViewModel

    private let onSettings: ((ProjectAgent) -> Void)?

    private var buttonContent: some View {
        HStack(spacing: 6) {
            self.buttonIcon
            self.chevron
        }
        .padding(.leading, 8)
        .padding(.trailing, 10)
        .padding(.vertical, 6)
        .background(self.chipBackground)
        .overlay(self.chipBorder)
    }

    @ViewBuilder private var buttonIcon: some View {
        if let agent = viewModel.selectedAgent {
            self.agentAvatar(for: agent)
            Text(agent.name)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
        } else {
            Image(systemName: "sparkles")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text("Agent")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
        }
    }

    private var chevron: some View {
        Image(systemName: "chevron.up.chevron.down")
            .font(.caption2.weight(.bold))
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

    @ViewBuilder
    private func agentAvatar(for agent: ProjectAgent) -> some View {
        if let ndk {
            NDKUIProfilePicture(ndk: ndk, pubkey: agent.pubkey, size: 20)
        } else {
            // Fallback when NDK is not available
            Circle()
                .fill(Color.gray.opacity(0.2))
                .frame(width: 20, height: 20)
                .overlay {
                    Text(agent.name.prefix(1).uppercased())
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
        }
    }
}
