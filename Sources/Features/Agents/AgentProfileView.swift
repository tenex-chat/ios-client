//
// AgentProfileView.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import SwiftUI
import TENEXCore

// MARK: - AgentProfileView

/// Displays detailed information about a project agent
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
            } else {
                content
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
            // Header Info
            HStack(spacing: 16) {
                // Avatar
                let initial = viewModel.name.prefix(1).uppercased()
                Text(initial)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 80, height: 80)
                    .background(Color.blue.gradient, in: Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.name)
                        .font(.title2)
                        .fontWeight(.bold)

                    if let role = viewModel.agentMetadata?.role {
                        Text(role)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.secondary.opacity(0.1), in: Capsule())
                    }

                    if viewModel.projectAgent.isGlobal {
                        Text("Global Agent")
                            .font(.caption)
                            .foregroundStyle(.blue)
                    }
                }
            }

            // Runtime Info (From ProjectStatus)
            section(title: "Runtime Configuration") {
                VStack(alignment: .leading, spacing: 8) {
                    if let model = viewModel.projectAgent.model {
                        HStack {
                            Text("Model:")
                                .foregroundStyle(.secondary)
                            Text(model)
                                .monospaced()
                        }
                    }

                    if !viewModel.projectAgent.tools.isEmpty {
                        HStack(alignment: .top) {
                            Text("Tools:")
                                .foregroundStyle(.secondary)
                            FlowLayout(spacing: 4) {
                                ForEach(viewModel.projectAgent.tools, id: \.self) { tool in
                                    Text(tool)
                                        .font(.caption)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
                                        .foregroundStyle(.blue)
                                }
                            }
                        }
                    }
                }
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(8)
            }

            // Description
            section(title: "Description") {
                Text(viewModel.description)
                    .foregroundStyle(.secondary)
            }

            // Instructions
            if let instructions = viewModel.instructions {
                section(title: "Instructions / System Prompt") {
                    Text(instructions) // TODO: Markdown support
                        .font(.body)
                        .textSelection(.enabled)
                        .monospaced()
                }
            }

            // Use Criteria
            let criteria = viewModel.agentMetadata?.useCriteria ?? []
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
        }
    }

    private var lessonsTab: some View {
        ContentUnavailableView("Coming Soon", systemImage: "book", description: Text("Agent lessons are under construction."))
    }

    private var settingsTab: some View {
        ContentUnavailableView("Coming Soon", systemImage: "gear", description: Text("Agent settings are under construction."))
    }

    // MARK: - Components

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
