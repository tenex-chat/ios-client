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
                .task {
                    self.profile = await self.ndk.profileManager.loadMetadata(for: self.agent.pubkey)
                }
        }
    }

    // MARK: Private

    @Binding private var isPresented: Bool
    @State private var selectedModel: String
    @State private var selectedTools: Set<String>
    @State private var expandedGroups: Set<String> = []
    @State private var profile: NDKUserMetadata?
    @State private var showRawProfileData = false

    private let agent: ProjectAgent
    private let availableModels: [String]
    private let projectReference: String
    private let ndk: NDK
    private let toolGroups: [ToolGroup]

    private var agentSection: some View {
        Section("Agent") {
            Button {
                self.showRawProfileData = true
            } label: {
                HStack {
                    self.profilePicture

                    VStack(alignment: .leading, spacing: 4) {
                        Text(self.profile?.bestDisplayName ?? self.agent.name)
                            .font(.headline)
                        Text(self.agent.pubkey.prefix(16) + "...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
        }
        .sheet(isPresented: self.$showRawProfileData) {
            RawProfileDataSheet(profile: self.profile, pubkey: self.agent.pubkey)
        }
    }

    @ViewBuilder
    private var profilePicture: some View {
        if let pictureURLString = profile?.picture,
           let pictureURL = URL(string: pictureURLString) {
            AsyncImage(url: pictureURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .failure:
                    self.fallbackIcon
                case .empty:
                    ProgressView()
                @unknown default:
                    self.fallbackIcon
                }
            }
            .frame(width: 44, height: 44)
            .clipShape(Circle())
        } else {
            self.fallbackIcon
        }
    }

    private var fallbackIcon: some View {
        Image(systemName: "person.circle.fill")
            .font(.largeTitle)
            .foregroundStyle(.secondary)
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
            #if os(iOS)
                .background(Color(.secondarySystemBackground))
            #else
                .background(Color(nsColor: .controlBackgroundColor))
            #endif
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - RawProfileDataSheet

/// Sheet displaying raw profile metadata for debugging
private struct RawProfileDataSheet: View {
    let profile: NDKUserMetadata?
    let pubkey: String

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    self.pubkeySection
                    self.metadataSection
                }
                .padding()
            }
            .navigationTitle("Raw Profile Data")
            #if !os(macOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            self.dismiss()
                        }
                    }
                }
        }
    }

    private var pubkeySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Pubkey")
                .font(.headline)
            Text(self.pubkey)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
    }

    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Metadata")
                .font(.headline)

            if let profile {
                if let metadata = profile.metadata {
                    self.metadataContent(metadata)
                } else {
                    Text("No metadata dictionary available")
                        .foregroundStyle(.secondary)
                }

                Divider()
                    .padding(.vertical, 8)

                self.parsedFieldsSection(profile)
            } else {
                Text("Profile not loaded")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func metadataContent(_ metadata: [String: Any]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            let options: JSONSerialization.WritingOptions = [.prettyPrinted, .sortedKeys]
            if let jsonData = try? JSONSerialization.data(withJSONObject: metadata, options: options),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                Text(jsonString)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .padding(12)
                    #if os(iOS)
                        .background(Color(.secondarySystemBackground))
                    #else
                        .background(Color(nsColor: .controlBackgroundColor))
                    #endif
                        .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    private func parsedFieldsSection(_ profile: NDKUserMetadata) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Parsed Fields")
                .font(.headline)

            self.fieldRow("name", profile.name)
            self.fieldRow("displayName", profile.displayName)
            self.fieldRow("bestDisplayName", profile.bestDisplayName)
            self.fieldRow("picture", profile.picture)
            self.fieldRow("banner", profile.banner)
            self.fieldRow("about", profile.about)
            self.fieldRow("website", profile.website)
            self.fieldRow("nip05", profile.nip05)
            self.fieldRow("lud16", profile.lud16)
            self.fieldRow("eventId", profile.eventId)
            self.fieldRow("updatedAt", "\(profile.updatedAt)")
        }
    }

    private func fieldRow(_ label: String, _ value: String?) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .frame(width: 100, alignment: .trailing)

            Text(value ?? "nil")
                .font(.caption.monospaced())
                .foregroundStyle(value != nil ? .primary : .tertiary)
                .textSelection(.enabled)
        }
    }
}
