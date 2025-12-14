//
// AgentListView.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import NDKSwiftCore
import SwiftUI
import TENEXCore

// MARK: - AgentListView

public struct AgentListView: View {
    // MARK: Lifecycle

    public init(viewModel: AgentListViewModel) {
        self.viewModel = viewModel
    }

    // MARK: Public

    public var body: some View {
        contentView
            .navigationTitle("Agents")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(
                        action: { showingEditor = true },
                        label: { Label("Add Agent", systemImage: "plus") }
                    )
                }
            }
            .sheet(isPresented: $showingEditor) {
                editorSheet
            }
    }

    // MARK: Private

    @State private var viewModel: AgentListViewModel
    @State private var showingEditor = false
    @Environment(\.ndk) private var ndk

    private var contentView: some View {
        Group {
            if viewModel.agents.isEmpty {
                ContentUnavailableView(
                    "No Agents",
                    systemImage: "person.slash",
                    description: Text("Create your first agent definition.")
                )
            } else {
                agentList
            }
        }
    }

    private var agentList: some View {
        List(viewModel.agents) { agent in
            NavigationLink(destination: AgentDetailView(agent: agent)) {
                VStack(alignment: .leading) {
                    Text(agent.name)
                        .font(.headline)
                    Text(agent.description ?? "No description")
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
                    AgentEditorView(ndk: ndk)
                }
            } else {
                Text("Error: NDK not available")
            }
        }
    }
}

// MARK: - AgentDetailView

struct AgentDetailView: View {
    let agent: AgentDefinition

    var body: some View {
        Form {
            Section(header: Text("Details")) {
                LabeledContent("Name", value: agent.name)
                LabeledContent("Role", value: agent.role)
                if let model = agent.model {
                    LabeledContent("Model", value: model)
                }
            }

            if let instructions = agent.instructions {
                Section(header: Text("Instructions")) {
                    Text(instructions)
                }
            }

            if let description = agent.description {
                Section(header: Text("Description")) {
                    Text(description)
                }
            }
        }
        .navigationTitle(agent.name)
    }
}
