//
// AgentProfileView.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import SwiftUI
import TENEXCore

// MARK: - AgentProfileView

/// Displays detailed information about an agent
/// Matches web implementation: AgentProfileTabs (Feed, Details, Lessons, Settings)
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
            } else if viewModel.agentDefinition != nil || viewModel.agentMetadata != nil {
                content
            } else if let error = viewModel.errorMessage {
                ContentUnavailableView("Error", systemImage: "exclamationmark.triangle", description: Text(error))
            } else {
                ContentUnavailableView("Not Found", systemImage: "person.slash", description: Text("Agent profile could not be found."))
            }
        }
        .task {
            await viewModel.load()
        }
        .navigationTitle(viewModel.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: Private

    @State private var viewModel: AgentProfileViewModel
    @State private var selectedTab: Tab = .details

    private enum Tab: String, CaseIterable, Identifiable {
        case feed = "Feed"
        case details = "Details"
        case lessons = "Lessons"
        case settings = "Settings"

        var id: String { rawValue }
    }

    private var content: some View {
        VStack(spacing: 0) {
            // Tabs Header
            Picker("Tab", selection: $selectedTab) {
                ForEach(Tab.allCases) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            // Tab Content
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    switch selectedTab {
                    case .feed:
                        feedTab
                    case .details:
                        detailsTab
                    case .lessons:
                        lessonsTab
                    case .settings:
                        settingsTab
                    }
                }
                .padding()
            }
        }
    }

    // MARK: - Tabs

    private var feedTab: some View {
        ContentUnavailableView("Coming Soon", systemImage: "bubble.left.and.bubble.right", description: Text("Agent feed is under construction."))
    }

    private var detailsTab: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Metadata Warning
            if viewModel.agentDefinition == nil && viewModel.agentMetadata != nil {
                metadataWarning
            }

            // Description
            section(title: "Description") {
                Text(viewModel.description)
                    .foregroundStyle(.secondary)
            }

            // Instructions
            if let instructions = viewModel.agentDefinition?.instructions ?? viewModel.agentMetadata?.instructions {
                section(title: "Instructions / System Prompt") {
                    Text(instructions) // TODO: Markdown support
                        .font(.body)
                        .textSelection(.enabled)
                        .monospaced()
                }
            }

            // Use Criteria
            let criteria = viewModel.agentDefinition?.useCriteria ?? viewModel.agentMetadata?.useCriteria ?? []
            if !criteria.isEmpty {
                section(title: "Use Criteria") {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(criteria, id: \.self) { item in
                            HStack(alignment: .top) {
                                Image(systemName: "circle.fill")
                                    .font(.system(size: 6))
                                    .padding(.top, 8)
                                Text(item)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            // Tools (Only in Definition)
            if let tools = viewModel.agentDefinition?.tools, !tools.isEmpty {
                section(title: "Tools") {
                    FlowLayout(spacing: 8) {
                        ForEach(tools, id: \.self) { tool in
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

            // MCP Servers (Only in Definition)
            if let mcpServers = viewModel.agentDefinition?.mcpServers, !mcpServers.isEmpty {
                section(title: "MCP Servers") {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(mcpServers, id: \.self) { server in
                            Text(server)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                                .foregroundStyle(.orange)
                        }
                    }
                }
            }
        }
    }

    private var lessonsTab: some View {
        ContentUnavailableView("Coming Soon", systemImage: "book", description: Text("Agent lessons are under construction."))
    }

    private var settingsTab: some View {
        ContentUnavailableView("Coming Soon", systemImage: "gear", description: Text("Agent settings are under construction."))
    }

    // MARK: - Components

    private var metadataWarning: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "sparkles")
                .foregroundStyle(.orange)
                .font(.title3)

            VStack(alignment: .leading, spacing: 4) {
                Text("Agent Metadata from Profile")
                    .font(.headline)
                    .foregroundStyle(.foreground)

                Text("This agent has metadata stored in their Nostr profile (kind:0 event). Convert it to an Agent Definition for better structure and compatibility.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
    }

    private func section<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            content()
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
