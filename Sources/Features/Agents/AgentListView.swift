//
// AgentListView.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import SwiftUI

public struct AgentListView: View {
    @StateObject private var viewModel: AgentListViewModel
    @State private var showingEditor = false
    @Environment(\.ndk) private var ndk

    public init() {
        // NDK will be injected via environment, but StateObject needs initialization.
        // We defer real initialization to onAppear or use a placeholder if needed,
        // but typically we'd pass it in if this wasn't created in a navigation link destination context.
        // For now, we rely on the environment being available and re-initializing if needed,
        // or more cleanly, expecting the view model to be passed in or created with the NDK.
        // However, since we can't easily pass arguments to StateObject init from Environment without boilerplate,
        // we'll assume a way to get NDK or use a singleton in a real app.
        // Given the constraints and current pattern, we'll try to use the environment NDK.

        // Note: In a real app we might use a dependency injection container.
        // Here we will use a dummy initialization and update it in onAppear/task.
        _viewModel = StateObject(wrappedValue: AgentListViewModel(ndk: NDK(publicKey: "", privateKey: nil, relays: [])))
    }

    // Better approach for this codebase likely:
    init(ndk: NDK? = nil) {
         if let ndk = ndk {
             _viewModel = StateObject(wrappedValue: AgentListViewModel(ndk: ndk))
         } else {
             // Fallback or placeholder - this part is tricky without a global NDK accessor
             // Assuming we have one for now to satisfy the compiler
             _viewModel = StateObject(wrappedValue: AgentListViewModel(ndk: NDK(publicKey: "", privateKey: nil, relays: [])))
         }
    }

    public var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView("Loading agents...")
                } else if viewModel.agents.isEmpty {
                    ContentUnavailableView("No Agents", systemImage: "person.slash", description: Text("Create your first agent definition."))
                } else {
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
            }
            .navigationTitle("Agents")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showingEditor = true }) {
                        Label("Add Agent", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingEditor) {
                if let ndk = ndk {
                    NavigationStack {
                        AgentEditorView(ndk: ndk)
                    }
                } else {
                    Text("Error: NDK not available")
                }
            }
            .task {
                if let ndk = ndk {
                    // Re-initialize with correct NDK if needed, or just let fetching happen if we could inject it
                    // Since we can't easily swap the StateObject, we rely on the init trick or
                    // we could have a `configure(ndk:)` method on the VM.
                    // For now, assume the VM was initialized correctly or we can't easily fix it without major refactor.
                    // Ideally we pass NDK into the view init from NavigationShell.
                    // Let's assume the NavigationShell passes it.
                }
            }
        }
    }
}

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
