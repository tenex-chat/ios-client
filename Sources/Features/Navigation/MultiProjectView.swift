//
// MultiProjectView.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import NDKSwiftCore
import SwiftUI

// MARK: - MultiProjectView

/// Main container for the multi-project column interface (macOS only)
///
/// Layout: HStack(ProjectsSidebar | ScrollView(ProjectColumns) | ConversationDrawer)
///
/// This view manages the state for open projects and conversation windows,
/// providing them via environment to child views. It displays:
/// - A sidebar with the projects list (240pt fixed width)
/// - Multiple project columns side-by-side (320pt each, horizontally scrollable)
/// - An optional conversation drawer that slides in from the right edge
///
/// The drawer overlays the main content area with a slide transition.
@MainActor
public struct MultiProjectView: View {
    // MARK: Lifecycle

    public init() {}

    // MARK: Public

    public var body: some View {
        ZStack(alignment: .trailing) {
            // Main content area
            HStack(spacing: 0) {
                // Left: Projects sidebar (240pt fixed)
                projectsSidebar
                    .frame(width: 240)

                Divider()

                // Center: Project columns (scrollable)
                projectColumnsArea
            }

            // Right: Conversation drawer (overlays when active)
            if windowManager.activeDrawer != nil {
                conversationDrawer
                    .transition(.move(edge: .trailing))
            }
        }
        .environment(openProjects)
        .environment(windowManager)
    }

    // MARK: Private

    @State private var openProjects = OpenProjectsStore()
    @State private var windowManager = WindowManagerStore()

    @Environment(DataStore.self) private var dataStore
    @Environment(NDKAuthManager.self) private var authManager

    // MARK: - Projects Sidebar

    private var projectsSidebar: some View {
        ProjectsSidebar()
    }

    // MARK: - Project Columns Area

    @ViewBuilder
    private var projectColumnsArea: some View {
        if openProjects.openProjectIDs.isEmpty {
            emptyStateView
        } else {
            projectColumnsScrollView
        }
    }

    private var emptyStateView: some View {
        ContentUnavailableView(
            "No Projects Open",
            systemImage: "folder",
            description: Text("Select a project from the sidebar to open it in a column")
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .textBackgroundColor))
    }

    private var projectColumnsScrollView: some View {
        ScrollView(.horizontal, showsIndicators: true) {
            HStack(spacing: 0) {
                ForEach(openProjects.openProjectIDs, id: \.self) { projectID in
                    projectColumn(for: projectID)
                        .frame(width: 320)

                    if projectID != openProjects.openProjectIDs.last {
                        Divider()
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .textBackgroundColor))
    }

    @ViewBuilder
    private func projectColumn(for projectID: String) -> some View {
        if let project = dataStore.projects.first(where: { $0.coordinate == projectID }) {
            ProjectColumn(
                project: project,
                projectCoordinate: projectID,
                currentUserPubkey: authManager.currentUser?.hexadecimalPublicKey
            )
        } else {
            projectNotFoundView(for: projectID)
        }
    }

    private func projectNotFoundView(for projectID: String) -> some View {
        VStack {
            Text("Project not found")
                .foregroundStyle(.secondary)

            Button("Close") {
                openProjects.close(projectID)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Conversation Drawer

    @ViewBuilder
    private var conversationDrawer: some View {
        if let drawer = windowManager.activeDrawer {
            ConversationDrawer(window: drawer)
        }
    }
}
