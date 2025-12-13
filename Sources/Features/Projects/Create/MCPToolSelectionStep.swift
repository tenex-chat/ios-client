//
// MCPToolSelectionStep.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import SwiftUI

struct MCPToolSelectionStep: View {
    @ObservedObject var viewModel: CreateProjectViewModel

    var body: some View {
        VStack {
            if viewModel.isLoadingTools {
                ProgressView("Loading tools...")
            } else if viewModel.availableTools.isEmpty {
                ContentUnavailableView("No Tools Found", systemImage: "hammer", description: Text("No MCP tools found."))
            } else {
                List {
                    ForEach(viewModel.availableTools) { tool in
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

                            if viewModel.selectedToolIds.contains(tool.id) {
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
                }
            }
        }
    }

    private func toggleSelection(for id: String) {
        if viewModel.selectedToolIds.contains(id) {
            viewModel.selectedToolIds.remove(id)
        } else {
            viewModel.selectedToolIds.insert(id)
        }
    }
}
