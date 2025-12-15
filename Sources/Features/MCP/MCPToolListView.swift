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

    public init(viewModel: MCPToolListViewModel) {
        self.viewModel = viewModel
    }

    // MARK: Public

    public var body: some View {
        self.contentView
            .navigationTitle("MCP Tools")
        #if os(iOS)
            .toolbar(.hidden, for: .tabBar)
        #endif
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(
                        action: { self.showingEditor = true },
                        label: { Label("Add Tool", systemImage: "plus") }
                    )
                }
            }
            .sheet(isPresented: self.$showingEditor) {
                self.editorSheet
            }
    }

    // MARK: Private

    @State private var viewModel: MCPToolListViewModel
    @State private var showingEditor = false
    @Environment(\.ndk) private var ndk

    private var contentView: some View {
        Group {
            if self.viewModel.tools.isEmpty {
                ContentUnavailableView(
                    "No Tools",
                    systemImage: "hammer",
                    description: Text("Create your first MCP tool definition.")
                )
            } else {
                self.toolList
            }
        }
    }

    private var toolList: some View {
        List(self.viewModel.tools) { tool in
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
                LabeledContent("Name", value: self.tool.name)
                LabeledContent("Command", value: self.tool.command)
            }

            Section(header: Text("Description")) {
                Text(self.tool.description)
            }

            if let params = tool.parameters {
                Section(header: Text("Parameters")) {
                    Text(String(describing: params))
                        .font(.monospaced(.caption)())
                }
            }
        }
        .navigationTitle(self.tool.name)
    }
}
