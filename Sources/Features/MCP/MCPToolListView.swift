//
// MCPToolListView.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import NDKSwiftCore
import SwiftUI
import TENEXCore

// MARK: - MCPToolListView

public struct MCPToolListView: View {
    // MARK: Lifecycle

    public init() {
        _viewModel = StateObject(wrappedValue: MCPToolListViewModel(ndk: NDK()))
    }

    init(ndk: NDK? = nil) {
        if let ndk {
            _viewModel = StateObject(wrappedValue: MCPToolListViewModel(ndk: ndk))
        } else {
            _viewModel = StateObject(wrappedValue: MCPToolListViewModel(ndk: NDK()))
        }
    }

    // MARK: Public

    public var body: some View {
        NavigationStack {
            contentView
                .navigationTitle("MCP Tools")
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button(
                            action: { showingEditor = true },
                            label: { Label("Add Tool", systemImage: "plus") }
                        )
                    }
                }
                .sheet(isPresented: $showingEditor) {
                    editorSheet
                }
        }
    }

    // MARK: Private

    @StateObject private var viewModel: MCPToolListViewModel
    @State private var showingEditor = false
    @Environment(\.ndk) private var ndk

    private var contentView: some View {
        Group {
            if viewModel.isLoading {
                ProgressView("Loading tools...")
            } else if viewModel.tools.isEmpty {
                ContentUnavailableView(
                    "No Tools",
                    systemImage: "hammer",
                    description: Text("Create your first MCP tool definition.")
                )
            } else {
                toolList
            }
        }
    }

    private var toolList: some View {
        List(viewModel.tools) { tool in
            NavigationLink(destination: MCPToolDetailView(tool: tool)) {
                VStack(alignment: .leading) {
                    Text(tool.name)
                        .font(.headline)
                    Text(tool.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private var editorSheet: some View {
        Group {
            if let ndk {
                NavigationStack {
                    MCPToolEditorView(ndk: ndk)
                }
            } else {
                Text("Error: NDK not available")
            }
        }
    }
}

// MARK: - MCPToolDetailView

struct MCPToolDetailView: View {
    let tool: MCPTool

    var body: some View {
        Form {
            Section(header: Text("Details")) {
                LabeledContent("Name", value: tool.name)
                LabeledContent("Command", value: tool.command)
            }

            Section(header: Text("Description")) {
                Text(tool.description)
            }

            if let params = tool.parameters {
                Section(header: Text("Parameters")) {
                    Text(String(describing: params))
                        .font(.monospaced(.caption)())
                }
            }
        }
        .navigationTitle(tool.name)
    }
}
