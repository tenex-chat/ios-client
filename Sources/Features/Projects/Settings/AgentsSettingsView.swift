//
// AgentsSettingsView.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import NDKSwiftCore
import os
import SwiftUI
import TENEXCore

// MARK: - AgentsSettingsView

/// Agents settings for project (add/remove agents, set primary)
struct AgentsSettingsView: View {
    // MARK: Lifecycle

    init(viewModel: ProjectSettingsViewModel) {
        self.viewModel = viewModel
    }

    // MARK: Internal

    var body: some View {
        Form {
            agentsSection
            saveSection
        }
        .navigationTitle("Agents")
        .sheet(isPresented: $showingAgentPicker, content: agentPickerSheet)
        .alert(
            "Project Updated",
            isPresented: $showingSuccessAlert,
            actions: successAlertActions,
            message: successAlertMessage
        )
        .alert(
            "Error",
            isPresented: .constant(viewModel.saveError != nil),
            actions: errorAlertActions,
            message: errorAlertMessage
        )
    }

    // MARK: Private

    private static let logger = Logger(subsystem: "com.tenex.ios", category: "AgentsSettings")

    @Environment(\.ndk) private var ndk
    @Environment(DataStore.self) private var dataStore: DataStore?
    @State private var showingAgentPicker = false
    @State private var showingSuccessAlert = false

    @Bindable private var viewModel: ProjectSettingsViewModel

    private var agentsSection: some View {
        Section(header: Text("Assigned Agents")) {
            if viewModel.selectedAgentIDs.isEmpty {
                ContentUnavailableView(
                    "No Agents",
                    systemImage: "person.2.slash",
                    description: Text("Add agents to this project")
                )
            } else {
                ForEach(Array(viewModel.selectedAgentIDs), id: \.self) { agentID in
                    AgentSettingsRow(
                        agentID: agentID,
                        isPrimary: agentID == viewModel.primaryAgentID,
                        onSetPrimary: { viewModel.primaryAgentID = agentID },
                        onRemove: {
                            viewModel.selectedAgentIDs.remove(agentID)
                            if viewModel.primaryAgentID == agentID {
                                viewModel.primaryAgentID = viewModel.selectedAgentIDs.first
                            }
                        }
                    )
                }
            }

            Button {
                showingAgentPicker = true
            } label: {
                Label("Add Agent", systemImage: "plus.circle.fill")
            }
        }
    }

    private var saveSection: some View {
        Section {
            Button("Save Changes") {
                Task {
                    do {
                        try await viewModel.save()
                        showingSuccessAlert = true
                    } catch {
                        // Error handled by viewModel.saveError
                    }
                }
            }
            .disabled(!viewModel.hasUnsavedChanges || viewModel.isSaving)

            if viewModel.isSaving {
                HStack {
                    ProgressView()
                    Text("Saving...")
                }
            }
        }
    }

    private func agentPickerSheet() -> some View {
        Group {
            if let dataStore {
                NavigationStack {
                    @Bindable var dataStoreBindable = dataStore
                    AgentPickerView(
                        selectedAgentIDs: $viewModel.selectedAgentIDs,
                        availableAgents: .constant(dataStore.agents)
                    )
                }
            }
        }
    }

    private func successAlertActions() -> some View {
        Button("OK") {}
    }

    private func successAlertMessage() -> some View {
        Text("Your changes have been published to Nostr.")
    }

    private func errorAlertActions() -> some View {
        Button("OK") { viewModel.saveError = nil }
    }

    private func errorAlertMessage() -> some View {
        Text(viewModel.saveError ?? "")
    }
}
