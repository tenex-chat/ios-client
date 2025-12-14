//
// ProjectListView.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import SwiftUI
import TENEXCore

// MARK: - ProjectListView

/// View displaying a list of projects
public struct ProjectListView: View {
    // MARK: Lifecycle

    /// Initialize the project list view
    /// - Parameters:
    ///   - viewModel: The view model for the project list
    ///   - selectedProjectID: Optional binding for split view selection mode
    public init(viewModel: ProjectListViewModel, selectedProjectID: Binding<String?>? = nil) {
        self.viewModel = viewModel
        _selectedProjectID = selectedProjectID ?? .constant(nil)
        usesSelection = selectedProjectID != nil
    }

    // MARK: Public

    public var body: some View {
        Group {
            if viewModel.projects.isEmpty {
                emptyView
            } else {
                projectList
            }
        }
        .navigationTitle("Projects")
        #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
        #endif
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(
                        action: { showingCreateWizard = true },
                        label: { Label("New Project", systemImage: "plus") }
                    )
                }

                ToolbarItem(placement: .automatic) {
                    groupFilterMenu
                }
            }
            .sheet(isPresented: $showingGroupEditor) {
                ProjectGroupEditorSheet(
                    isPresented: $showingGroupEditor,
                    allProjects: allProjects,
                    existingGroup: editingGroup,
                    onSave: { name, projectIDs in
                        if let existingGroup = editingGroup {
                            var updatedGroup = existingGroup
                            updatedGroup.name = name
                            updatedGroup.projectIDs = projectIDs
                            viewModel.updateGroup(updatedGroup)
                        } else {
                            viewModel.createGroup(name: name, projectIDs: projectIDs)
                        }
                    },
                    onDelete: editingGroup != nil ? {
                        if let group = editingGroup {
                            viewModel.deleteGroup(id: group.id)
                        }
                    } : nil
                )
            }
            .sheet(isPresented: $showingCreateWizard) {
                if let dataStore, let ndk {
                    CreateProjectWizardView(ndk: ndk, dataStore: dataStore)
                }
            }
    }

    // MARK: Private

    @State private var viewModel: ProjectListViewModel
    @State private var showingCreateWizard = false
    @State private var showingGroupEditor = false
    @State private var editingGroup: ProjectGroup?
    @Binding private var selectedProjectID: String?
    @Environment(\.ndk) private var ndk
    @Environment(DataStore.self) private var dataStore: DataStore?

    private let usesSelection: Bool

    private var allProjects: [Project] {
        viewModel.allNonArchivedProjects
    }

    private var emptyStateTitle: String {
        viewModel.selectedGroupID != nil ? "No Projects in This Group" : "No Projects"
    }

    private var emptyStateMessage: String {
        viewModel.selectedGroupID != nil
            ? "This group doesn't have any projects yet"
            : "You don't have any projects yet"
    }

    private var selectedGroup: ProjectGroup? {
        viewModel.groups.first { $0.id == viewModel.selectedGroupID }
    }

    private var groupFilterMenuLabel: String {
        selectedGroup?.name ?? "All Projects"
    }

    @ViewBuilder private var groupMenuItems: some View {
        allProjectsButton
        groupListSection
        newGroupButton
        selectedGroupActions
    }

    private var allProjectsButton: some View {
        Button {
            viewModel.selectedGroupID = nil
        } label: {
            Label("All Projects", systemImage: viewModel.selectedGroupID == nil ? "checkmark" : "")
        }
    }

    @ViewBuilder private var groupListSection: some View {
        if !viewModel.groups.isEmpty {
            Divider()
            ForEach(viewModel.groups) { group in
                Button {
                    viewModel.selectedGroupID = group.id
                } label: {
                    let icon = viewModel.selectedGroupID == group.id ? "checkmark" : ""
                    Label(group.name, systemImage: icon)
                }
            }
            Divider()
        }
    }

    private var newGroupButton: some View {
        Button {
            editingGroup = nil
            showingGroupEditor = true
        } label: {
            Label("New Group", systemImage: "plus")
        }
    }

    @ViewBuilder private var selectedGroupActions: some View {
        if let selectedGroup {
            Divider()
            Button {
                editingGroup = selectedGroup
                showingGroupEditor = true
            } label: {
                Label("Edit Group", systemImage: "pencil")
            }
            Button(role: .destructive) {
                viewModel.deleteGroup(id: selectedGroup.id)
            } label: {
                Label("Delete Group", systemImage: "trash")
            }
        }
    }

    private var groupFilterMenu: some View {
        Menu {
            groupMenuItems
        } label: {
            Label(groupFilterMenuLabel, systemImage: "line.3.horizontal.decrease.circle")
        }
    }

    @ViewBuilder private var projectList: some View {
        if usesSelection {
            // Split view mode: use selection binding
            List(viewModel.projects, selection: $selectedProjectID) { project in
                projectRowContent(for: project)
                    .tag(project.coordinate)
            }
            .listStyle(.plain)
        } else {
            // Stack navigation mode: use NavigationLink
            List {
                ForEach(viewModel.projects) { project in
                    NavigationLink(value: AppRoute.project(id: project.id)) {
                        projectRowContent(for: project)
                    }
                }
            }
            .listStyle(.plain)
        }
    }

    private var emptyView: some View {
        VStack(spacing: 20) {
            Image(systemName: "folder.fill")
                .font(.system(size: 60))
                .foregroundStyle(.blue)

            Text(emptyStateTitle)
                .font(.title)
                .fontWeight(.semibold)

            Text(emptyStateMessage)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button("Create New Project") {
                showingCreateWizard = true
            }
            .buttonStyle(.borderedProminent)
            .padding(.top)
        }
    }

    @ViewBuilder
    private func projectRowContent(for project: Project) -> some View {
        let isOnline = dataStore?.isProjectOnline(projectCoordinate: project.coordinate) ?? false
        ProjectRow(project: project, isOnline: isOnline)
            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
            .listRowSeparator(.hidden)
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                archiveButton(for: project)
            }
            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                if !isOnline {
                    startButton(for: project)
                }
            }
    }

    private func archiveButton(for project: Project) -> some View {
        Button(role: .destructive) {
            Task { await viewModel.archiveProject(id: project.id) }
        } label: {
            Label("Archive", systemImage: "archivebox")
        }
        .tint(.orange)
    }

    private func startButton(for project: Project) -> some View {
        Button {
            Task { try? await dataStore?.startProject(project) }
        } label: {
            Label("Start", systemImage: "play.fill")
        }
        .tint(.green)
    }
}

// MARK: - ProjectRow

/// Row component displaying a single project
struct ProjectRow: View {
    // MARK: Internal

    let project: Project
    var isOnline = false

    var body: some View {
        HStack(spacing: 8) {
            avatarView
            projectInfo
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        #if os(iOS)
            .hoverEffect(.highlight)
        #endif
            .accessibilityElement(children: .combine)
            .accessibilityLabel(project.title)
            .accessibilityHint(project.description ?? "Open project")
    }

    // MARK: Private

    /// Dynamic Type scaling for avatar size
    @ScaledMetric(relativeTo: .body) private var avatarSize: CGFloat = 40
    @ScaledMetric(relativeTo: .body) private var avatarFontSize: CGFloat = 16

    private var avatarView: some View {
        ZStack(alignment: .bottomTrailing) {
            RoundedRectangle(cornerRadius: 12)
                .fill(project.color)
                .frame(width: avatarSize, height: avatarSize)
                .overlay {
                    Text(project.title.prefix(1).uppercased())
                        .font(.system(size: avatarFontSize, weight: .semibold))
                        .foregroundStyle(.white)
                }
            statusIndicator
        }
    }

    private var statusIndicator: some View {
        Circle()
            .fill(isOnline ? Color.green : Color.gray.opacity(0.5))
            .frame(width: 14, height: 14)
            .overlay {
                Circle()
                #if os(macOS)
                    .stroke(Color(nsColor: .windowBackgroundColor), lineWidth: 2)
                #else
                    .stroke(Color(uiColor: .systemBackground), lineWidth: 2)
                #endif
            }
            .shadow(color: isOnline ? .green.opacity(0.5) : .clear, radius: 4)
            .offset(x: 2, y: 2)
    }

    private var projectInfo: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(project.title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary)

            if let description = project.description {
                Text(description)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
