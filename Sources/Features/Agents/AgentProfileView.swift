//
// AgentProfileView.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import SwiftUI
import TENEXCore

// MARK: - AgentProfileView

/// Displays detailed information about an agent (Agent Definition)
public struct AgentProfileView: View {
    // MARK: Lifecycle

    public init(viewModel: AgentProfileViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    // MARK: Public

    public var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView()
            } else if let agent = viewModel.agentDefinition {
                content(for: agent)
            } else if let error = viewModel.errorMessage {
                ContentUnavailableView("Error", systemImage: "exclamationmark.triangle", description: Text(error))
            } else {
                ContentUnavailableView("Not Found", systemImage: "person.slash", description: Text("Agent definition could not be found."))
            }
        }
        .task {
            await viewModel.load()
        }
        .navigationTitle(viewModel.agentDefinition?.name ?? viewModel.projectAgent?.name ?? "Agent")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: Private

    @State private var viewModel: AgentProfileViewModel
    @State private var selectedTab: Tab = .details

    private enum Tab {
        case details
        case phases
    }

    private func content(for agent: NDKAgentDefinition) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                headerView(agent: agent)

                // Tabs
                if !agent.phases.isEmpty {
                    Picker("Tab", selection: $selectedTab) {
                        Text("Details").tag(Tab.details)
                        Text("Phases (\(agent.phases.count))").tag(Tab.phases)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                }

                // Content
                switch selectedTab {
                case .details:
                    detailsView(agent: agent)
                case .phases:
                    phasesView(agent: agent)
                }
            }
            .padding(.vertical)
        }
    }

    private func headerView(agent: NDKAgentDefinition) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 16) {
                // Avatar
                let initial = agent.name.prefix(1).uppercased()
                Text(initial)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 80, height: 80)
                    .background(Color.blue.gradient, in: Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(agent.name)
                        .font(.title2)
                        .fontWeight(.bold)

                    Text(agent.role)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.1), in: Capsule())

                    if let version = agent.version {
                        Text("v\(version)")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }

                Spacer()
            }
            .padding(.horizontal)
        }
    }

    private func detailsView(agent: NDKAgentDefinition) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            // Description
            section(title: "Description") {
                Text(agent.description)
                    .foregroundStyle(.secondary)
            }

            // Instructions
            if !agent.instructions.isEmpty {
                section(title: "Instructions") {
                    Text(agent.instructions) // TODO: Markdown support
                        .font(.body)
                        .textSelection(.enabled)
                }
            }

            // Use Criteria
            if !agent.useCriteria.isEmpty {
                section(title: "Use Criteria") {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(agent.useCriteria, id: \.self) { criteria in
                            HStack(alignment: .top) {
                                Image(systemName: "circle.fill")
                                    .font(.system(size: 6))
                                    .padding(.top, 8)
                                Text(criteria)
                            }
                        }
                    }
                }
            }

            // Tools
            if !agent.tools.isEmpty {
                section(title: "Tools") {
                    FlowLayout(spacing: 8) {
                        ForEach(agent.tools, id: \.self) { tool in
                            Text(tool)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                                .foregroundStyle(.blue)
                        }
                    }
                }
            }

            // MCP Servers
            if !agent.mcpServers.isEmpty {
                section(title: "MCP Servers") {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(agent.mcpServers, id: \.self) { server in
                            Text(server) // TODO: Resolve MCP server name if possible
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                                .foregroundStyle(.orange)
                        }
                    }
                }
            }

            // Metadata
            section(title: "Metadata") {
                VStack(alignment: .leading, spacing: 8) {
                    labeledValue("Author", value: String(agent.pubkey.prefix(8)) + "...")
                    labeledValue("Created", value: agent.createdAt.formatted(date: .abbreviated, time: .shortened))
                    labeledValue("Event Kind", value: String(agent.event.kind))
                }
            }
        }
        .padding(.horizontal)
    }

    private func phasesView(agent: NDKAgentDefinition) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(Array(agent.phases.enumerated()), id: \.offset) { index, phase in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Phase \(index + 1)")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(.blue)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.1), in: Capsule())

                        Text(phase.name)
                            .font(.headline)
                    }

                    Text(phase.instructions)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(Color(UIColor.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(.horizontal)
    }

    private func section<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            content()
        }
    }

    private func labeledValue(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
                .font(.caption)
            Spacer()
            Text(value)
                .font(.caption)
                .monospaced()
        }
    }
}

// MARK: - FlowLayout

/// Simple flow layout for tags
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        let height = rows.last?.maxY ?? 0
        return CGSize(width: proposal.width ?? 0, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        for row in rows {
            for element in row.elements {
                element.subview.place(at: CGPoint(x: bounds.minX + element.x, y: bounds.minY + row.y), proposal: proposal)
            }
        }
    }

    struct Row {
        var elements: [Element] = []
        var y: CGFloat = 0
        var height: CGFloat = 0

        var maxY: CGFloat { y + height }
    }

    struct Element {
        var subview: LayoutSubview
        var x: CGFloat
    }

    func computeRows(proposal: ProposedViewSize, subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var currentRow = Row()
        var x: CGFloat = 0
        let maxWidth = proposal.width ?? .infinity

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if x + size.width > maxWidth && !currentRow.elements.isEmpty {
                currentRow.y = (rows.last?.maxY ?? 0) + spacing
                rows.append(currentRow)
                currentRow = Row()
                x = 0
            }

            currentRow.elements.append(Element(subview: subview, x: x))
            currentRow.height = max(currentRow.height, size.height)
            x += size.width + spacing
        }

        if !currentRow.elements.isEmpty {
            currentRow.y = (rows.last?.maxY ?? 0) + spacing
            rows.append(currentRow)
        }

        return rows
    }
}
