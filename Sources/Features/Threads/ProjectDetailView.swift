//
// ProjectDetailView.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import SwiftUI
import TENEXCore

// MARK: - ProjectDetailView

/// View displaying project details with tabbed interface
public struct ProjectDetailView: View {
    // MARK: Lifecycle

    /// Initialize the project detail view
    /// - Parameters:
    ///   - project: The project to display
    ///   - ndk: The NDK instance for fetching data
    public init(project: Project, ndk: any NDKSubscribing) {
        self.project = project
        self.ndk = ndk
    }

    // MARK: Public

    public var body: some View {
        VStack(spacing: 0) {
            // Project header with gradient background
            projectHeader

            // Icon toolbar with tabs
            tabToolbar

            // Content area based on selected tab
            tabContent
        }
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    // MARK: Private

    private enum Tab: String, CaseIterable {
        case threads
        case docs
        case agents
        case feed

        // MARK: Internal

        var icon: String {
            switch self {
            case .threads:
                "message.fill"
            case .docs:
                "doc.fill"
            case .agents:
                "person.2.fill"
            case .feed:
                "list.bullet"
            }
        }

        var title: String {
            rawValue.capitalized
        }
    }

    @State private var selectedTab: Tab = .threads

    private let project: Project
    private let ndk: any NDKSubscribing

    private var projectHeader: some View {
        VStack(spacing: 12) {
            // Project title
            Text(project.title)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.primary)

            // Online agent count (placeholder)
            HStack(spacing: 4) {
                Circle()
                    .fill(.green)
                    .frame(width: 8, height: 8)

                Text("0 agents online")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(
            project.color.opacity(0.15)
                .ignoresSafeArea(edges: .top)
        )
    }

    private var tabToolbar: some View {
        HStack(spacing: 0) {
            ForEach(Tab.allCases, id: \.self) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 22))
                            .foregroundStyle(selectedTab == tab ? project.color : .secondary)

                        Text(tab.title)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(selectedTab == tab ? project.color : .secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.plain)
            }
        }
        #if os(iOS)
        .background(Color(.systemBackground))
        #else
        .background(Color(nsColor: .windowBackgroundColor))
        #endif
        .overlay(
            Rectangle()
            #if os(iOS)
                .fill(Color(.separator))
            #else
                .fill(Color(nsColor: .separatorColor))
            #endif
                .frame(height: 1),
            alignment: .bottom
        )
    }

    @ViewBuilder private var tabContent: some View {
        switch selectedTab {
        case .threads:
            ThreadListView(projectID: project.coordinate, ndk: ndk)
        case .docs:
            comingSoonView(for: "Docs")
        case .agents:
            comingSoonView(for: "Agents")
        case .feed:
            comingSoonView(for: "Feed")
        }
    }

    private func comingSoonView(for feature: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "sparkles")
                .font(.system(size: 60))
                .foregroundStyle(project.color)

            Text("\(feature) Coming Soon")
                .font(.title2)
                .fontWeight(.semibold)

            Text("This feature is under development")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
