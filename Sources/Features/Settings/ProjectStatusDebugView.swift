//
// ProjectStatusDebugView.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import SwiftUI
import TENEXCore
import TENEXShared

// MARK: - ProjectStatusDebugView

/// Debug view showing project status events (kind:24010) from DataStore
struct ProjectStatusDebugView: View {
    // MARK: Internal

    var body: some View {
        List {
            summarySection
            projectsSection
        }
        .navigationTitle("Project Status")
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
            .refreshable {
                // DataStore automatically refreshes via subscription
            }
    }

    // MARK: Private

    @Environment(DataStore.self) private var dataStore

    private var onlineProjectCount: Int {
        dataStore.projects.count { project in
            dataStore.isProjectOnline(projectCoordinate: project.coordinate)
        }
    }

    @ViewBuilder private var summarySection: some View {
        Section("Summary") {
            HStack {
                Text("Total Projects")
                Spacer()
                Text("\(dataStore.projects.count)")
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text("Online Projects")
                Spacer()
                Text("\(onlineProjectCount)")
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder private var projectsSection: some View {
        Section("Projects") {
            if dataStore.projects.isEmpty {
                Text("No projects found")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(dataStore.projects, id: \.id) { project in
                    ProjectStatusRow(project: project)
                }
            }
        }
    }
}

// MARK: - ProjectStatusRow

private struct ProjectStatusRow: View {
    // MARK: Lifecycle

    init(project: Project) {
        self.project = project
    }

    // MARK: Internal

    let project: Project

    var body: some View {
        Button {
            selectedProject = project
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(status?.isOnline == true ? Color.green : Color.secondary)
                        .frame(width: 8, height: 8)

                    Text(project.title)
                        .font(.body)
                        .foregroundStyle(.primary)
                }

                if let status {
                    HStack(spacing: 12) {
                        Label("\(status.agents.count)", systemImage: "person.2")
                        Label("\(uniqueModelCount)", systemImage: "cpu")
                        Label("\(totalToolCount)", systemImage: "wrench.and.screwdriver")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    Text("Last seen: \(FormattingUtilities.relative(status.createdAt))")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                } else {
                    Text("No status")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
        .sheet(item: $selectedProject) { project in
            NavigationStack {
                ProjectStatusDetailView(project: project)
            }
        }
    }

    // MARK: Private

    @Environment(DataStore.self) private var dataStore
    @State private var selectedProject: Project?

    private var status: ProjectStatus? {
        dataStore.getProjectStatus(projectCoordinate: project.coordinate)
    }

    private var uniqueModelCount: Int {
        guard let status else {
            return 0
        }
        let models = Set(status.agents.compactMap(\.model))
        return models.count
    }

    private var totalToolCount: Int {
        guard let status else {
            return 0
        }
        return status.agents.flatMap(\.tools).count
    }
}

// MARK: - ProjectStatusDetailView

private struct ProjectStatusDetailView: View {
    // MARK: Lifecycle

    init(project: Project) {
        self.project = project
    }

    // MARK: Internal

    let project: Project

    var body: some View {
        List {
            statusSection
            if let status {
                agentsSection(status: status)
                modelsSection(status: status)
                toolsSection(status: status)
            }
        }
        .navigationTitle(project.title)
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
    }

    // MARK: Private

    @Environment(DataStore.self) private var dataStore
    @Environment(\.dismiss) private var dismiss

    private var status: ProjectStatus? {
        dataStore.getProjectStatus(projectCoordinate: project.coordinate)
    }

    @ViewBuilder private var statusSection: some View {
        Section("Status") {
            LabeledContent("Online") {
                if let status {
                    Text(status.isOnline ? "Yes" : "No")
                        .foregroundStyle(status.isOnline ? .green : .secondary)
                } else {
                    Text("Unknown")
                        .foregroundStyle(.secondary)
                }
            }

            if let status {
                LabeledContent("Last Seen") {
                    Text(FormattingUtilities.relative(status.createdAt))
                        .foregroundStyle(.secondary)
                }

                LabeledContent("Timestamp") {
                    Text(FormattingUtilities.shortDateTime(status.createdAt))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private func agentsSection(status: ProjectStatus) -> some View {
        Section("Agents (\(status.agents.count))") {
            if status.agents.isEmpty {
                Text("No agents online")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(status.agents, id: \.pubkey) { agent in
                    AgentDetailRow(agent: agent)
                }
            }
        }
    }

    @ViewBuilder
    private func modelsSection(status: ProjectStatus) -> some View {
        let models = Set(status.agents.compactMap(\.model))
        Section("Models (\(models.count))") {
            if models.isEmpty {
                Text("No models assigned")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(models).sorted(), id: \.self) { model in
                    Text(model)
                        .font(.system(.body, design: .monospaced))
                }
            }
        }
    }

    @ViewBuilder
    private func toolsSection(status: ProjectStatus) -> some View {
        let allTools = status.agents.flatMap(\.tools)
        let uniqueTools = Set(allTools)

        Section("Tools") {
            LabeledContent("Unique") {
                Text("\(uniqueTools.count)")
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            LabeledContent("Total") {
                Text("\(allTools.count)")
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - AgentDetailRow

private struct AgentDetailRow: View {
    // MARK: Lifecycle

    init(agent: ProjectAgent) {
        self.agent = agent
    }

    // MARK: Internal

    let agent: ProjectAgent

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 8) {
                LabeledContent("Pubkey") {
                    Text(agent.pubkey.prefix(16) + "...")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }

                if let model = agent.model {
                    LabeledContent("Model") {
                        Text(model)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }

                if !agent.tools.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Tools (\(agent.tools.count))")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        ForEach(agent.tools, id: \.self) { tool in
                            Text("• \(tool)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.leading, 8)
                        }
                    }
                    .padding(.top, 4)
                }
            }
            .padding(.vertical, 4)
        } label: {
            HStack(spacing: 8) {
                Text(agent.name)
                    .font(.body)

                if agent.isGlobal {
                    Text("Global")
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.2))
                        .foregroundStyle(.blue)
                        .cornerRadius(4)
                }

                if let model = agent.model {
                    Text(model)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.1))
                        .foregroundStyle(.secondary)
                        .cornerRadius(4)
                }

                if !agent.tools.isEmpty {
                    Text("\(agent.tools.count) tools")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
        }
    }

    // MARK: Private

    @State private var isExpanded = false
}
