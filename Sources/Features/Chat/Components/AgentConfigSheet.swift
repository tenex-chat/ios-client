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
        self.projectReference = projectReference
        self.ndk = ndk

        // Initialize selected values from agent
        _selectedModel = State(initialValue: agent.model ?? "")
        _selectedTools = State(initialValue: Set(agent.tools))

        // Group tools intelligently
        self.toolGroups = ToolGrouper.groupTools(availableTools)
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
                            self.saveConfiguration()
                        }
                    }
                }
        }
    }

    // MARK: Private

    @Binding private var isPresented: Bool
    @State private var selectedModel: String
    @State private var selectedTools: Set<String>
    @State private var expandedGroups: Set<String> = []

    private let agent: ProjectAgent
    private let availableModels: [String]
    private let projectReference: String
    private let ndk: NDK
    private let toolGroups: [ToolGroup]

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
        Section {
            if self.toolGroups.isEmpty {
                Text("No tools available")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(self.toolGroups) { group in
                    ToolGroupRow(
                        group: group,
                        isExpanded: self.expandedGroups.contains(group.id),
                        selectedTools: self.selectedTools,
                        onToggleExpand: {
                            self.toggleGroupExpansion(group.id)
                        },
                        onToggleAll: { enable in
                            self.toggleAllTools(in: group, enable: enable)
                        },
                        onToggleTool: { tool in
                            self.toggleTool(tool)
                        }
                    )
                }
            }
        } header: {
            Text("Tools")
        }
    }

    private func toggleGroupExpansion(_ groupID: String) {
        if self.expandedGroups.contains(groupID) {
            self.expandedGroups.remove(groupID)
        } else {
            self.expandedGroups.insert(groupID)
        }
    }

    private func toggleAllTools(in group: ToolGroup, enable: Bool) {
        for tool in group.tools {
            if enable {
                self.selectedTools.insert(tool)
            } else {
                self.selectedTools.remove(tool)
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

    private func saveConfiguration() {
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

        // Fire-and-forget: Create and publish event in background
        Task {
            do {
                let event = try await NDKEventBuilder(ndk: ndk)
                    .kind(24_020)
                    .setTags(tags)
                    .content("")
                    .build()

                try await self.ndk.publish(event)
            } catch {
                // Nostr fire-and-forget: silently fail, optimistic UI
            }
        }

        // Close immediately (optimistic UI)
        self.isPresented = false
    }
}

// MARK: - ToolGroupRow

/// Row displaying a tool group with expand/collapse and checkboxes
private struct ToolGroupRow: View {
    // MARK: Internal

    let group: ToolGroup
    let isExpanded: Bool
    let selectedTools: Set<String>
    let onToggleExpand: () -> Void
    let onToggleAll: (Bool) -> Void
    let onToggleTool: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            self.groupHeader
            self.expandedToolsList
        }
    }

    // MARK: Private

    private var isFullySelected: Bool {
        self.group.tools.allSatisfy { self.selectedTools.contains($0) }
    }

    private var isPartiallySelected: Bool {
        let selectedCount = self.group.tools.count { self.selectedTools.contains($0) }
        return selectedCount > 0 && selectedCount < self.group.tools.count
    }

    private var selectedCount: Int {
        self.group.tools.count { self.selectedTools.contains($0) }
    }

    private var checkboxImageName: String {
        if self.isFullySelected {
            "checkmark.square.fill"
        } else if self.isPartiallySelected {
            "minus.square.fill"
        } else {
            "square"
        }
    }

    private var groupHeader: some View {
        Button {
            if !self.group.isSingleTool {
                self.onToggleExpand()
            }
        } label: {
            self.groupHeaderContent
        }
        .buttonStyle(.plain)
    }

    private var groupHeaderContent: some View {
        HStack(spacing: 12) {
            self.expandCollapseChevron
            self.groupCheckbox
            self.groupNameAndCount
            Spacer()
            self.toolCountBadge
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }

    private var expandCollapseChevron: some View {
        Group {
            if !self.group.isSingleTool {
                Image(systemName: self.isExpanded ? "chevron.down" : "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 16)
            } else {
                Spacer()
                    .frame(width: 16)
            }
        }
    }

    private var groupCheckbox: some View {
        Button {
            self.onToggleAll(!self.isFullySelected)
        } label: {
            Image(systemName: self.checkboxImageName)
                .font(.title3)
                .foregroundStyle(self.isFullySelected || self.isPartiallySelected ? .blue : .secondary)
        }
        .buttonStyle(.plain)
    }

    private var groupNameAndCount: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(self.group.name)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)

            if !self.group.isSingleTool {
                Text("\(self.selectedCount)/\(self.group.tools.count) selected")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder private var toolCountBadge: some View {
        if !self.group.isSingleTool {
            Text("\(self.group.tools.count)")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(.secondarySystemFill))
                .clipShape(Capsule())
        }
    }

    @ViewBuilder private var expandedToolsList: some View {
        if !self.group.isSingleTool, self.isExpanded {
            VStack(spacing: 0) {
                ForEach(self.group.tools, id: \.self) { tool in
                    self.toolRow(for: tool)
                }
            }
        }
    }

    private func toolRow(for tool: String) -> some View {
        Button {
            self.onToggleTool(tool)
        } label: {
            HStack(spacing: 12) {
                Spacer()
                    .frame(width: 16)

                Image(systemName: self.selectedTools.contains(tool) ? "checkmark.square.fill" : "square")
                    .font(.title3)
                    .foregroundStyle(self.selectedTools.contains(tool) ? .blue : .secondary)

                Text(tool)
                    .font(.caption.monospaced())
                    .foregroundStyle(.primary)

                Spacer()
            }
            .padding(.vertical, 6)
            .padding(.leading, 12)
            .background(Color(.secondarySystemBackground))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
