//
// AgentConfigSheet.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import NDKSwiftCore
import SwiftUI
import TENEXCore

// MARK: - AgentConfigSheet

/// Sheet for configuring an agent's model and tools
public struct AgentConfigSheet: View {
    // MARK: Lifecycle

    public init(
        isPresented: Binding<Bool>,
        agent: ProjectAgent,
        availableModels: [String],
        availableTools: [String],
        projectReference: String,
        ndk: NDK
    ) {
        _isPresented = isPresented
        self.agent = agent
        self.availableModels = availableModels
        self.availableTools = availableTools
        self.projectReference = projectReference
        self.ndk = ndk

        // Initialize selected values from agent
        _selectedModel = State(initialValue: agent.model ?? "")
        _selectedTools = State(initialValue: Set(agent.tools))
    }

    // MARK: Public

    public var body: some View {
        NavigationStack {
            Form {
                self.agentSection
                self.modelSection
                self.toolsSection
            }
            .navigationTitle("Configure Agent")
            #if !os(macOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            self.isPresented = false
                        }
                    }

                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            Task {
                                await self.saveConfiguration()
                            }
                        }
                        .disabled(self.isSaving)
                    }
                }
        }
    }

    // MARK: Private

    @Binding private var isPresented: Bool
    @State private var selectedModel: String
    @State private var selectedTools: Set<String>
    @State private var isSaving = false

    private let agent: ProjectAgent
    private let availableModels: [String]
    private let availableTools: [String]
    private let projectReference: String
    private let ndk: NDK

    private var agentSection: some View {
        Section("Agent") {
            HStack {
                Image(systemName: "person.circle.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.blue)

                VStack(alignment: .leading, spacing: 4) {
                    Text(self.agent.name)
                        .font(.headline)
                    Text(self.agent.pubkey.prefix(16) + "...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var modelSection: some View {
        Section("Model") {
            if self.availableModels.isEmpty {
                Text("No models available")
                    .foregroundStyle(.secondary)
            } else {
                Picker("Select Model", selection: self.$selectedModel) {
                    Text("Select model...").tag("")
                    ForEach(self.availableModels, id: \.self) { model in
                        Text(model).tag(model)
                    }
                }
                .pickerStyle(.menu)
            }
        }
    }

    private var toolsSection: some View {
        Section("Tools") {
            if self.availableTools.isEmpty {
                Text("No tools available")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(self.availableTools, id: \.self) { tool in
                    ToolToggleRow(
                        tool: tool,
                        isSelected: self.selectedTools.contains(tool)
                    ) {
                        self.toggleTool(tool)
                    }
                }
            }
        }
    }

    private func toggleTool(_ tool: String) {
        if self.selectedTools.contains(tool) {
            self.selectedTools.remove(tool)
        } else {
            self.selectedTools.insert(tool)
        }
    }

    private func saveConfiguration() async {
        self.isSaving = true
        defer { isSaving = false }

        do {
            // Build tags for kind:24020 event
            var tags: [[String]] = [
                ["p", agent.pubkey],
                ["a", self.projectReference],
            ]

            // Add model tag if selected
            if !self.selectedModel.isEmpty {
                tags.append(["model", self.selectedModel])
            }

            // Add tool tags
            for tool in self.selectedTools.sorted() {
                tags.append(["tool", tool])
            }

            // Create and publish the agent config update event
            let event = try await NDKEventBuilder(ndk: ndk)
                .kind(24_020)
                .setTags(tags)
                .content("")
                .build()

            try await self.ndk.publish(event)

            // Close sheet on success
            self.isPresented = false
        } catch {
            // Failed to save agent configuration
        }
    }
}

// MARK: - ToolToggleRow

/// Row with a checkbox for toggling a tool
private struct ToolToggleRow: View {
    let tool: String
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: self.onToggle) {
            HStack {
                Image(systemName: self.isSelected ? "checkmark.square.fill" : "square")
                    .font(.title3)
                    .foregroundStyle(self.isSelected ? .blue : .secondary)

                Text(self.tool)
                    .font(.subheadline.monospaced())
                    .foregroundStyle(.primary)

                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
