//
// MCPToolListView.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import SwiftUI

public struct MCPToolListView: View {
    @StateObject private var viewModel: MCPToolListViewModel
    @State private var showingEditor = false
    @Environment(\.ndk) private var ndk

    public init() {
         _viewModel = StateObject(wrappedValue: MCPToolListViewModel(ndk: NDK(publicKey: "", privateKey: nil, relays: [])))
    }

    init(ndk: NDK? = nil) {
         if let ndk = ndk {
             _viewModel = StateObject(wrappedValue: MCPToolListViewModel(ndk: ndk))
         } else {
             _viewModel = StateObject(wrappedValue: MCPToolListViewModel(ndk: NDK(publicKey: "", privateKey: nil, relays: [])))
         }
    }

    public var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView("Loading tools...")
                } else if viewModel.tools.isEmpty {
                    ContentUnavailableView("No Tools", systemImage: "hammer", description: Text("Create your first MCP tool definition."))
                } else {
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
            }
            .navigationTitle("MCP Tools")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showingEditor = true }) {
                        Label("Add Tool", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingEditor) {
                if let ndk = ndk {
                    NavigationStack {
                        MCPToolEditorView(ndk: ndk)
                    }
                } else {
                    Text("Error: NDK not available")
                }
            }
        }
    }
}

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
