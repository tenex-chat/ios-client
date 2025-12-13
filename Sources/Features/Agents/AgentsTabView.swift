//
// AgentsTabView.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

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
            if viewModel.isLoading, viewModel.agents.isEmpty {
                loadingView
            } else if let error = viewModel.errorMessage {
                errorView(error)
            } else if viewModel.agents.isEmpty {
                emptyView
            } else {
                agentsList
            }
        }
        .navigationTitle("Agents")
        .task {
            await viewModel.subscribe()
        }
        .refreshable {
            await viewModel.refresh()
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
                ForEach(viewModel.agents) { agent in
                    NavigationLink(value: AppRoute.agentProfile(agent: agent)) {
                        AgentRow(agent: agent)
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
                    await viewModel.refresh()
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

    var body: some View {
        HStack(spacing: 12) {
            // Agent avatar (placeholder - will use NDKUIProfilePicture when NDKSwiftUI bug is fixed)
            agentAvatar

            // Agent info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(agent.name)
                        .font(.system(size: 16, weight: .semibold))

                    if agent.isGlobal {
                        globalBadge
                    }
                }

                if let model = agent.model {
                    Text(model)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }

                if !agent.tools.isEmpty {
                    toolsView
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }

    // MARK: Private

    private var agentAvatar: some View {
        let initial = agent.name.prefix(1).uppercased()
        return Text(initial)
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 48, height: 48)
            .background(Color.blue.gradient, in: Circle())
    }

    private var globalBadge: some View {
        Text("Global")
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(.blue.opacity(0.8), in: Capsule())
    }

    private var toolsView: some View {
        HStack(spacing: 4) {
            Image(systemName: "wrench.and.screwdriver")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)

            Text(agent.tools.prefix(3).joined(separator: ", "))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            if agent.tools.count > 3 {
                Text("+\(agent.tools.count - 3)")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
        }
    }
}
