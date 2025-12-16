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
    ///   - currentUserPubkey: The current user's pubkey (for thread interactions)
    public init(project: Project, projectCoordinate: String, currentUserPubkey: String?) {
        self.project = project
        self.projectCoordinate = projectCoordinate
        self.currentUserPubkey = currentUserPubkey
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
    private let currentUserPubkey: String?

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
            ThreadsTabContent(
                projectID: projectCoordinate,
                currentUserPubkey: currentUserPubkey
            )
        case .docs:
            DocsTabContent(
                projectID: projectCoordinate,
                currentUserPubkey: currentUserPubkey
            )
        case .agents:
            AgentsTabContent(
                projectID: projectCoordinate,
                currentUserPubkey: currentUserPubkey
            )
        case .feed:
            FeedTabContent(
                projectID: projectCoordinate,
                currentUserPubkey: currentUserPubkey
            )
        }
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
