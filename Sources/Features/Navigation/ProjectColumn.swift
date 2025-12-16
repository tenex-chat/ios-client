//
// ProjectColumn.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import SwiftUI
import TENEXCore

// MARK: - ProjectColumn

/// A single project column in the multi-project interface
///
/// This view displays a project with tabs for different content types:
/// - Threads: List of conversation threads
/// - Docs: Project documentation
/// - Agents: Associated agents
/// - Feed: Activity feed
///
/// The column has a fixed width of 320pt and includes a header with:
/// - Project title and description (if available)
/// - Close button to remove the column
@MainActor
public struct ProjectColumn: View {
    // MARK: Lifecycle

    /// Initialize a project column
    /// - Parameters:
    ///   - project: The project to display
    ///   - projectCoordinate: The project coordinate string (kind:pubkey:dTag)
    public init(project: Project, projectCoordinate: String) {
        self.project = project
        self.projectCoordinate = projectCoordinate
    }

    // MARK: Public

    public var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            tabSelector
            Divider()
            tabContent
        }
        .frame(width: 320)
    }

    // MARK: Private

    private let project: Project
    private let projectCoordinate: String

    @State private var selectedTab: ProjectTab = .threads
    @Environment(OpenProjectsStore.self) private var openProjects

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(project.title)
                    .font(.headline)

                if let description = project.description {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer()

            Button {
                openProjects.close(projectCoordinate)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding()
    }

    // MARK: - Tab Selector

    private var tabSelector: some View {
        Picker("Tab", selection: $selectedTab) {
            ForEach(ProjectTab.allCases) { tab in
                Text(tab.title).tag(tab)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Tab Content

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .threads:
            threadsTabPlaceholder
        case .docs:
            docsTabPlaceholder
        case .agents:
            agentsTabPlaceholder
        case .feed:
            feedTabPlaceholder
        }
    }

    private var threadsTabPlaceholder: some View {
        VStack(spacing: 8) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("Threads")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Thread list will appear here")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var docsTabPlaceholder: some View {
        VStack(spacing: 8) {
            Image(systemName: "doc.text")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("Docs")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Documentation will appear here")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var agentsTabPlaceholder: some View {
        VStack(spacing: 8) {
            Image(systemName: "person.2")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("Agents")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Agents will appear here")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var feedTabPlaceholder: some View {
        VStack(spacing: 8) {
            Image(systemName: "list.bullet")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("Feed")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Activity feed will appear here")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - ProjectTab

/// Tabs available in a project column
private enum ProjectTab: String, CaseIterable, Identifiable {
    case threads
    case docs
    case agents
    case feed

    var id: String { rawValue }

    var title: String {
        switch self {
        case .threads:
            return "Threads"
        case .docs:
            return "Docs"
        case .agents:
            return "Agents"
        case .feed:
            return "Feed"
        }
    }
}
