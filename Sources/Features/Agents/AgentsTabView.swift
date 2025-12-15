//
// AgentsTabView.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import NDKSwiftCore
import NDKSwiftUI
import SwiftUI
import TENEXCore

// MARK: - AgentsTabView

/// Tab view showing online agents for a project
/// Agents are fetched from ProjectStatus (kind:24010)
public struct AgentsTabView: View {
    // MARK: Lifecycle

    /// Initialize the agents tab view
    /// - Parameter viewModel: The agents tab view model
    public init(viewModel: AgentsTabViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    // MARK: Public

    public var body: some View {
        Group {
            if self.viewModel.isLoading, self.viewModel.agents.isEmpty {
                self.loadingView
            } else if let error = viewModel.errorMessage {
                self.errorView(error)
            } else if self.viewModel.agents.isEmpty {
                self.emptyView
            } else {
                self.agentsList
            }
        }
        .navigationTitle("Agents")
        .task {
            await self.viewModel.subscribe()
        }
    }

    // MARK: Private

    @State private var viewModel: AgentsTabViewModel

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Loading agents...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var emptyView: some View {
        ContentUnavailableView {
            Label("No Agents Online", systemImage: "person.2.slash")
        } description: {
            Text("No agents are currently online for this project.")
        }
    }

    private var agentsList: some View {
        List {
            Section {
                ForEach(self.viewModel.agents) { agent in
                    NavigationLink(value: AppRoute.agentProfile(pubkey: agent.pubkey)) {
                        AgentRow(agent: agent, ndk: self.viewModel.ndk)
                    }
                }
            } header: {
                Text("Online Agents")
            } footer: {
                Text("These agents are available to assist you in this project.")
            }
        }
    }

    private func errorView(_ message: String) -> some View {
        ContentUnavailableView {
            Label("Error", systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        } actions: {
            Button("Try Again") {
                Task {
                    await self.viewModel.subscribe()
                }
            }
        }
    }
}

// MARK: - AgentRow

/// Row view for displaying an agent
struct AgentRow: View {
    // MARK: Internal

    let agent: ProjectAgent
    let ndk: NDK

    var body: some View {
        HStack(spacing: 12) {
            NDKUIProfilePicture(ndk: self.ndk, pubkey: self.agent.pubkey, size: 48)

            // Agent info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(self.agent.name)
                        .font(.callout.weight(.semibold))

                    if self.agent.isGlobal {
                        self.globalBadge
                    }
                }

                if let model = agent.model {
                    Text(model)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if !self.agent.tools.isEmpty {
                    self.toolsView
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }

    // MARK: Private

    private var globalBadge: some View {
        Text("Global")
            .font(.caption.weight(.medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(.blue.opacity(0.8), in: Capsule())
    }

    private var toolsView: some View {
        HStack(spacing: 4) {
            Image(systemName: "wrench.and.screwdriver")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(self.agent.tools.prefix(3).joined(separator: ", "))
                .font(.caption)
                .foregroundStyle(.secondary)

            if self.agent.tools.count > 3 {
                Text("+\(self.agent.tools.count - 3)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}
