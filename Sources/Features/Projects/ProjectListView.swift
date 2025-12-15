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
    /// - Parameter viewModel: The view model for the project list
    public init(viewModel: ProjectListViewModel) {
        self.viewModel = viewModel
    }

    // MARK: Public

    public var body: some View {
        Group {
            if self.viewModel.projects.isEmpty {
                self.emptyView
            } else {
                self.projectList
            }
        }
        .navigationTitle("Projects")
        #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
        #endif
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(
                        action: { self.showingCreateWizard = true },
                        label: { Label("New Project", systemImage: "plus") }
                    )
                }

                #if os(iOS)
                    ToolbarItem(placement: .topBarLeading) {
                        self.groupFilterMenu
                    }
                #else
                    ToolbarItem(placement: .navigation) {
                        self.groupFilterMenu
                    }
                #endif
            }
            .sheet(isPresented: self.$showingGroupEditor) {
                ProjectGroupEditorSheet(
                    isPresented: self.$showingGroupEditor,
                    allProjects: self.allProjects,
                    existingGroup: self.editingGroup,
                    onSave: { name, projectIDs in
                        if let existingGroup = editingGroup {
                            var updatedGroup = existingGroup
                            updatedGroup.name = name
                            updatedGroup.projectIDs = projectIDs
                            self.viewModel.updateGroup(updatedGroup)
                        } else {
                            self.viewModel.createGroup(name: name, projectIDs: projectIDs)
                        }
                    },
                    onDelete: self.editingGroup != nil ? {
                        if let group = editingGroup {
                            self.viewModel.deleteGroup(id: group.id)
                        }
                    } : nil
                )
            }
            .sheet(isPresented: self.$showingCreateWizard) {
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
    @Environment(\.ndk) private var ndk
    @Environment(DataStore.self) private var dataStore: DataStore?

    private var allProjects: [Project] {
        self.viewModel.allNonArchivedProjects
    }

    private var emptyStateTitle: String {
        self.viewModel.selectedGroupID != nil ? "No Projects in This Group" : "No Projects"
    }

    private var emptyStateMessage: String {
        self.viewModel.selectedGroupID != nil
            ? "This group doesn't have any projects yet"
            : "You don't have any projects yet"
    }

    private var selectedGroup: ProjectGroup? {
        self.viewModel.groups.first { $0.id == self.viewModel.selectedGroupID }
    }

    private var groupFilterMenuLabel: String {
        self.selectedGroup?.name ?? "All Projects"
    }

    @ViewBuilder private var groupMenuItems: some View {
        self.allProjectsButton
        self.groupListSection
        self.newGroupButton
        self.selectedGroupActions
    }

    private var allProjectsButton: some View {
        Button {
            self.viewModel.selectedGroupID = nil
        } label: {
            Label("All Projects", systemImage: self.viewModel.selectedGroupID == nil ? "checkmark" : "")
        }
    }

    @ViewBuilder private var groupListSection: some View {
        if !self.viewModel.groups.isEmpty {
            Divider()
            ForEach(self.viewModel.groups) { group in
                Button {
                    self.viewModel.selectedGroupID = group.id
                } label: {
                    let icon = self.viewModel.selectedGroupID == group.id ? "checkmark" : ""
                    Label(group.name, systemImage: icon)
                }
            }
            Divider()
        }
    }

    private var newGroupButton: some View {
        Button {
            self.editingGroup = nil
            self.showingGroupEditor = true
        } label: {
            Label("New Group", systemImage: "plus")
        }
    }

    @ViewBuilder private var selectedGroupActions: some View {
        if let selectedGroup {
            Divider()
            Button {
                self.editingGroup = selectedGroup
                self.showingGroupEditor = true
            } label: {
                Label("Edit Group", systemImage: "pencil")
            }
            Button(role: .destructive) {
                self.viewModel.deleteGroup(id: selectedGroup.id)
            } label: {
                Label("Delete Group", systemImage: "trash")
            }
        }
    }

    private var groupFilterMenu: some View {
        Menu {
            self.groupMenuItems
        } label: {
            Label(self.groupFilterMenuLabel, systemImage: "line.3.horizontal.decrease.circle")
        }
    }

    private var projectList: some View {
        List {
            ForEach(self.viewModel.projects) { project in
                self.projectRow(for: project)
            }
        }
        .listStyle(.plain)
    }

    private var emptyView: some View {
        VStack(spacing: 20) {
            Image(systemName: "folder.fill")
                .font(.system(size: 60))
                .foregroundStyle(.blue)

            Text(self.emptyStateTitle)
                .font(.title)
                .fontWeight(.semibold)

            Text(self.emptyStateMessage)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button("Create New Project") {
                self.showingCreateWizard = true
            }
            .buttonStyle(.borderedProminent)
            .padding(.top)
        }
    }

    @ViewBuilder
    private func projectRow(for project: Project) -> some View {
        let isOnline = self.dataStore?.isProjectOnline(projectCoordinate: project.coordinate) ?? false
        NavigationLink(value: AppRoute.project(id: project.id)) {
            ProjectRow(project: project, isOnline: isOnline)
        }
        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
        .listRowSeparator(.hidden)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            self.archiveButton(for: project)
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            if !isOnline {
                self.startButton(for: project)
            }
        }
    }

    private func archiveButton(for project: Project) -> some View {
        Button(role: .destructive) {
            Task { await self.viewModel.archiveProject(id: project.id) }
        } label: {
            Label("Archive", systemImage: "archivebox")
        }
        .tint(.orange)
    }

    private func startButton(for project: Project) -> some View {
        Button {
            Task { try? await self.dataStore?.startProject(project) }
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
        HStack(spacing: 12) {
            self.avatarView
            self.projectInfo
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }

    // MARK: Private

    /// Dynamic Type scaling for avatar size
    @ScaledMetric(relativeTo: .title) private var avatarSize: CGFloat = 56
    @ScaledMetric(relativeTo: .title) private var avatarFontSize: CGFloat = 24

    private var avatarView: some View {
        ZStack(alignment: .bottomTrailing) {
            RoundedRectangle(cornerRadius: 12)
                .fill(self.project.color)
                .frame(width: self.avatarSize, height: self.avatarSize)
                .overlay {
                    Text(self.project.title.prefix(1).uppercased())
                        .font(.system(size: self.avatarFontSize, weight: .semibold))
                        .foregroundStyle(.white)
                }
            self.statusIndicator
        }
    }

    private var statusIndicator: some View {
        Circle()
            .fill(self.isOnline ? Color.green : Color.gray.opacity(0.5))
            .frame(width: 14, height: 14)
            .overlay {
                Circle()
                #if os(iOS)
                    .stroke(Color(uiColor: .systemBackground), lineWidth: 2)
                #else
                    .stroke(Color(nsColor: .windowBackgroundColor), lineWidth: 2)
                #endif
            }
            .shadow(color: self.isOnline ? .green.opacity(0.5) : .clear, radius: 4)
            .offset(x: 2, y: 2)
    }

    private var projectInfo: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(self.project.title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.primary)

            if let description = project.description {
                Text(description)
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
