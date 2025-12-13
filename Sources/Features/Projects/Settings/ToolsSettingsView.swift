//
// ToolsSettingsView.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import NDKSwiftCore
import os
import SwiftUI
import TENEXCore

// MARK: - ToolsSettingsView

/// Tools settings for project (add/remove MCP tools)
struct ToolsSettingsView: View {
    // MARK: Lifecycle

    init(viewModel: ProjectSettingsViewModel) {
        self.viewModel = viewModel
    }

    // MARK: Internal

    var body: some View {
        Form {
            toolsSection
            saveSection
        }
        .navigationTitle("Tools")
        .sheet(isPresented: $showingToolPicker, content: toolPickerSheet)
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

    private static let logger = Logger(subsystem: "com.tenex.ios", category: "ToolsSettings")

    @Environment(\.ndk) private var ndk
    @Environment(DataStore.self) private var dataStore
    @State private var showingToolPicker = false
    @State private var showingSuccessAlert = false

    @Bindable private var viewModel: ProjectSettingsViewModel

    private var toolsSection: some View {
        Section(header: Text("Assigned Tools")) {
            if viewModel.selectedToolIDs.isEmpty {
                ContentUnavailableView(
                    "No Tools",
                    systemImage: "wrench.and.screwdriver.fill",
                    description: Text("Add MCP tools to this project")
                )
            } else {
                ForEach(Array(viewModel.selectedToolIDs), id: \.self) { toolID in
                    MCPToolSettingsRow(toolID: toolID) {
                        viewModel.selectedToolIDs.remove(toolID)
                    }
                }
            }

            Button {
                showingToolPicker = true
            } label: {
                Label("Add Tool", systemImage: "plus.circle.fill")
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

    private func toolPickerSheet() -> some View {
        Group {
            if let dataStore {
                NavigationStack {
                    MCPToolPickerView(
                        selectedToolIDs: $viewModel.selectedToolIDs,
                        availableTools: .constant(dataStore.tools)
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
