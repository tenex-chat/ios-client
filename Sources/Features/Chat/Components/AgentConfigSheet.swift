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
                agentSection
                modelSection
                toolsSection
            }
            .navigationTitle("Configure Agent")
            #if !os(macOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            isPresented = false
                        }
                    }

                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            Task {
                                await saveConfiguration()
                            }
                        }
                        .disabled(isSaving)
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
                    .font(.system(size: 32))
                    .foregroundStyle(.blue)

                VStack(alignment: .leading, spacing: 4) {
                    Text(agent.name)
                        .font(.headline)
                    Text(agent.pubkey.prefix(16) + "...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var modelSection: some View {
        Section("Model") {
            if availableModels.isEmpty {
                Text("No models available")
                    .foregroundStyle(.secondary)
            } else {
                Picker("Select Model", selection: $selectedModel) {
                    Text("Select model...").tag("")
                    ForEach(availableModels, id: \.self) { model in
                        Text(model).tag(model)
                    }
                }
                .pickerStyle(.menu)
            }
        }
    }

    private var toolsSection: some View {
        Section("Tools") {
            if availableTools.isEmpty {
                Text("No tools available")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(availableTools, id: \.self) { tool in
                    ToolToggleRow(
                        tool: tool,
                        isSelected: selectedTools.contains(tool)
                    ) {
                        toggleTool(tool)
                    }
                }
            }
        }
    }

    private func toggleTool(_ tool: String) {
        if selectedTools.contains(tool) {
            selectedTools.remove(tool)
        } else {
            selectedTools.insert(tool)
        }
    }

    private func saveConfiguration() async {
        isSaving = true
        defer { isSaving = false }

        do {
            // Build tags for kind:24020 event
            var tags: [[String]] = [
                ["p", agent.pubkey],
                ["a", projectReference],
            ]

            // Add model tag if selected
            if !selectedModel.isEmpty {
                tags.append(["model", selectedModel])
            }

            // Add tool tags
            for tool in selectedTools.sorted() {
                tags.append(["tool", tool])
            }

            // Create and publish the agent config update event
            let event = try await NDKEventBuilder(ndk: ndk)
                .kind(24_020)
                .setTags(tags)
                .content("")
                .build()

            try await ndk.publish(event)

            // Close sheet on success
            isPresented = false
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
        Button(action: onToggle) {
            HStack {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .font(.system(size: 20))
                    .foregroundStyle(isSelected ? .blue : .secondary)

                Text(tool)
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundStyle(.primary)

                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
