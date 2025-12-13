//
// MCPToolPickerView.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import SwiftUI
import TENEXCore

// MARK: - MCPToolPickerView

/// Sheet for selecting MCP tools from available list
struct MCPToolPickerView: View {
    // MARK: Lifecycle

    init(selectedToolIDs: Binding<Set<String>>, availableTools: Binding<[MCPTool]>) {
        _selectedToolIDs = selectedToolIDs
        _availableTools = availableTools
    }

    // MARK: Internal

    var body: some View {
        List {
            toolsListContent
        }
        .navigationTitle("Select Tools")
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
    @Binding private var selectedToolIDs: Set<String>
    @Binding private var availableTools: [MCPTool]

    @ViewBuilder private var toolsListContent: some View {
        if availableTools.isEmpty {
            ContentUnavailableView(
                "No Tools Available",
                systemImage: "wrench.and.screwdriver.fill",
                description: Text("Create MCP tools to add them to your project")
            )
        } else {
            ForEach(availableTools) { tool in
                Button {
                    toggleTool(tool.id)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(tool.name)
                                .font(.body)
                                .foregroundStyle(.primary)

                            if let description = tool.description {
                                Text(description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                        }

                        Spacer()

                        if selectedToolIDs.contains(tool.id) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.blue)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func toggleTool(_ toolID: String) {
        if selectedToolIDs.contains(toolID) {
            selectedToolIDs.remove(toolID)
        } else {
            selectedToolIDs.insert(toolID)
        }
    }
}
