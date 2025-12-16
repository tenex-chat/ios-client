//
// ProjectsSidebar.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

#if os(macOS)
import SwiftUI
import TENEXCore

// MARK: - ProjectsSidebar

/// Sidebar displaying the list of projects with open state indicators
///
/// This view shows all available projects from the DataStore and displays
/// a blue dot indicator for projects that are currently open as columns.
/// Clicking a project toggles its open/closed state without navigation.
///
/// Layout is optimized for a 240pt fixed width sidebar.
@MainActor
public struct ProjectsSidebar: View {
    // MARK: Lifecycle

    public init() {}

    // MARK: Public

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            header
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

            Divider()

            // Projects list
            if dataStore.projects.isEmpty {
                emptyStateView
            } else {
                projectsList
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }

    // MARK: Private

    @Environment(DataStore.self) private var dataStore
    @Environment(OpenProjectsStore.self) private var openProjects

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("Projects")
                .font(.headline)
                .foregroundStyle(.primary)

            Spacer()

            if dataStore.isLoadingProjects {
                ProgressView()
                    .controlSize(.small)
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "folder")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)

            Text("No Projects")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("Create a project to get started")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    // MARK: - Projects List

    private var projectsList: some View {
        List {
            ForEach(dataStore.projects, id: \.id) { project in
                SidebarProjectRow(
                    project: project,
                    isOpen: openProjects.isOpen(project.coordinate)
                )
                .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
                .listRowBackground(Color.clear)
                .contentShape(Rectangle())
                .onTapGesture {
                    openProjects.toggle(project.coordinate)
                }
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
    }
}

// MARK: - SidebarProjectRow

/// A single row displaying a project with open state indicator
private struct SidebarProjectRow: View {
    // MARK: Internal

    let project: Project
    let isOpen: Bool

    var body: some View {
        HStack(spacing: 8) {
            // Project avatar with open state indicator
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(project.color)
                    .frame(width: 32, height: 32)
                    .overlay {
                        Text(project.title.prefix(1).uppercased())
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                    }

                // Open state indicator dot
                if isOpen {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 10, height: 10)
                        .overlay {
                            Circle()
                                .stroke(Color(nsColor: .controlBackgroundColor), lineWidth: 2)
                        }
                        .offset(x: 3, y: -3)
                }
            }

            // Project info
            VStack(alignment: .leading, spacing: 2) {
                Text(project.title)
                    .font(.body)
                    .lineLimit(1)

                if let description = project.description {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 4)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview

#Preview {
    Text("ProjectsSidebar Preview")
        .frame(width: 240, height: 600)
}
#endif
