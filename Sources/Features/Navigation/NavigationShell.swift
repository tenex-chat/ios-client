//
// NavigationShell.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import NDKSwiftCore
import OSLog
import SwiftUI
import TENEXCore

// MARK: - NavigationShell

/// Main navigation container for the app
/// Uses NavigationStack for iPhone, prepared for NavigationSplitView on iPad (future milestone)
public struct NavigationShell: View {
    // MARK: Lifecycle

    public init() {}

    // MARK: Public

    public var body: some View {
        NavigationStack(path: $router.path) {
            rootView
                .navigationDestination(for: AppRoute.self) { route in
                    destinationView(for: route)
                }
                .toolbar {
                    #if os(iOS)
                        ToolbarItem(placement: .topBarTrailing) {
                            settingsButton
                        }
                    #else
                        ToolbarItem(placement: .primaryAction) {
                            settingsButton
                        }
                    #endif
                }
        }
        .onOpenURL { url in
            handleDeepLink(url)
        }
    }

    // MARK: Private

    @Environment(NDKAuthManager.self) private var authManager
    @Environment(DataStore.self) private var dataStore: DataStore?
    @Environment(\.ndk) private var ndk
    @State private var router = NavigationRouter()

    // MARK: - Root View

    private var rootView: some View {
        Group {
            if let dataStore {
                ProjectListView(
                    viewModel: ProjectListViewModel(
                        dataStore: dataStore
                    )
                )
            } else {
                Text("Loading...")
            }
        }
    }

    // MARK: - Settings

    private var settingsButton: some View {
        Menu {
            NavigationLink(value: AppRoute.settings) {
                Label("Settings", systemImage: "gearshape")
            }
            if dataStore != nil {
                NavigationLink(value: AppRoute.agentList) {
                    Label("Agents", systemImage: "person.2")
                }
                NavigationLink(value: AppRoute.mcpToolList) {
                    Label("MCP Tools", systemImage: "hammer")
                }
            }
        } label: {
            Label("Menu", systemImage: "ellipsis.circle")
        }
    }

    // MARK: - Destination Views

    @ViewBuilder
    // swiftlint:disable cyclomatic_complexity
    private func destinationView(for route: AppRoute) -> some View {
        switch route {
        case .projectList:
            if let dataStore {
                ProjectListView(
                    viewModel: ProjectListViewModel(
                        dataStore: dataStore
                    )
                )
            } else {
                Text("Loading...")
            }

        case let .project(id):
            if let project = dataStore?.projects.first(where: { $0.id == id }) {
                ProjectDetailView(project: project)
            } else {
                Text("Project not found")
            }

        case let .threadList(projectID):
            ThreadListView(projectID: projectID, userPubkey: authManager.activePubkey)

        case let .thread(projectID, _):
            // Deep link to specific thread - show thread list (user can select thread)
            ThreadListView(projectID: projectID, userPubkey: authManager.activePubkey)

        case let .voiceMode(projectID, _):
            // Voice mode must be started from within a chat
            ThreadListView(projectID: projectID, userPubkey: authManager.activePubkey)

        case let .agents(projectID):
            if let ndk {
                AgentsTabView(viewModel: AgentsTabViewModel(ndk: ndk, projectID: projectID))
            } else {
                Text("Loading...")
            }

        case let .agentProfile(pubkey):
            if let ndk {
                AgentProfileView(pubkey: pubkey, ndk: ndk)
            } else {
                Text("Loading...")
            }

        case .agentList:
            if let dataStore {
                AgentListView(viewModel: AgentListViewModel(dataStore: dataStore))
            } else {
                Text("Loading...")
            }

        case .mcpToolList:
            if let dataStore {
                MCPToolListView(viewModel: MCPToolListViewModel(dataStore: dataStore))
            } else {
                Text("Loading...")
            }

        case .settings:
            SettingsView()
        }
    }

    // swiftlint:enable cyclomatic_complexity

    // MARK: - Deep Link Handling

    private func handleDeepLink(_ url: URL) {
        do {
            try router.handleDeepLink(url)
        } catch {
            Logger().error("Failed to handle deep link: \(error.localizedDescription)")
        }
    }
}
