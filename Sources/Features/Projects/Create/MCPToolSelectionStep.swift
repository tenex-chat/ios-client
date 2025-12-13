//
// MCPToolSelectionStep.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import SwiftUI
import TENEXCore

struct MCPToolSelectionStep: View {
    // MARK: Internal

    @Bindable var viewModel: CreateProjectViewModel

    var body: some View {
        VStack {
            if viewModel.isLoadingTools {
                ProgressView("Loading tools...")
            } else if viewModel.availableTools.isEmpty {
                emptyView
            } else {
                toolList
            }
        }
    }

    // MARK: Private

    private var emptyView: some View {
        ContentUnavailableView(
            "No Tools Found",
            systemImage: "hammer",
            description: Text("No MCP tools found.")
        )
    }

    private var toolList: some View {
        List {
            ForEach(viewModel.availableTools) { tool in
                toolRow(for: tool)
            }
        }
    }

    private func toolRow(for tool: MCPTool) -> some View {
        HStack {
            VStack(alignment: .leading) {
                Text(tool.name)
                    .font(.headline)
                Text(tool.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            if viewModel.selectedToolIDs.contains(tool.id) {
                Image(systemName: "checkmark.square.fill")
                    .foregroundColor(.accentColor)
            } else {
                Image(systemName: "square")
                    .foregroundColor(.secondary)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            toggleSelection(for: tool.id)
        }
    }

    private func toggleSelection(for id: String) {
        if viewModel.selectedToolIDs.contains(id) {
            viewModel.selectedToolIDs.remove(id)
        } else {
            viewModel.selectedToolIDs.insert(id)
        }
    }
}
