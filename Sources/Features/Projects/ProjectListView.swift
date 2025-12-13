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
        VStack(spacing: 0) {
            // Project group tabs
            ProjectGroupTabBar(
                selectedGroupID: $viewModel.selectedGroupID,
                groups: viewModel.groups,
                onCreateGroup: {
                    editingGroup = nil
                    showingGroupEditor = true
                },
                onEditGroup: { group in
                    editingGroup = group
                    showingGroupEditor = true
                },
                onDeleteGroup: { group in
                    viewModel.deleteGroup(id: group.id)
                }
            )

            Divider()

            // Project list or empty view
            Group {
                if viewModel.projects.isEmpty {
                    emptyView
                } else {
                    projectList
                }
            }
        }
        .navigationTitle("Projects")
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
    }

    // MARK: Private

    @State private var viewModel: ProjectListViewModel
    @State private var showingCreateWizard = false
    @State private var showingGroupEditor = false
    @State private var editingGroup: ProjectGroup?
    @Environment(\.ndk) private var ndk
    @Environment(DataStore.self) private var dataStore: DataStore?

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

    private var projectList: some View {
        List {
            ForEach(viewModel.projects) { project in
                NavigationLink(value: AppRoute.project(id: project.id)) {
                    ProjectRow(project: project)
                }
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                .listRowSeparator(.hidden)
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        Task {
                            await viewModel.archiveProject(id: project.id)
                        }
                    } label: {
                        Label("Archive", systemImage: "archivebox")
                    }
                    .tint(.orange)
                }
            }
        }
        .listStyle(.plain)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(
                    action: { showingCreateWizard = true },
                    label: { Label("New Project", systemImage: "plus") }
                )
            }
        }
        .sheet(isPresented: $showingCreateWizard) {
            if let ndk, let dataStore {
                CreateProjectWizardView(ndk: ndk, dataStore: dataStore)
            }
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
        .sheet(isPresented: $showingCreateWizard) {
            if let ndk, let dataStore {
                CreateProjectWizardView(ndk: ndk, dataStore: dataStore)
            }
        }
    }
}

// MARK: - ProjectRow

/// Row component displaying a single project
struct ProjectRow: View {
    // MARK: Lifecycle

    init(project: Project) {
        self.project = project
    }

    // MARK: Internal

    var body: some View {
        HStack(spacing: 12) {
            // Project avatar with HSL color
            RoundedRectangle(cornerRadius: 12)
                .fill(project.color)
                .frame(width: 56, height: 56)
                .overlay {
                    Text(project.title.prefix(1).uppercased())
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(.white)
                }

            // Project info with separator
            VStack(alignment: .leading, spacing: 4) {
                Text(project.title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.primary)

                if let description = project.description {
                    Text(description)
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 12)
            .overlay(alignment: .bottom) {
                Divider()
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .contentShape(Rectangle())
    }

    // MARK: Private

    private let project: Project
}
