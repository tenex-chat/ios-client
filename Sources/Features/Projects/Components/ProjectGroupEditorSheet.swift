//
// ProjectGroupEditorSheet.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import SwiftUI
import TENEXCore

// MARK: - ProjectGroupEditorSheet

/// Sheet for creating or editing a project group
struct ProjectGroupEditorSheet: View {
    // MARK: Lifecycle

    init(
        isPresented: Binding<Bool>,
        allProjects: [Project],
        existingGroup: ProjectGroup? = nil,
        onSave: @escaping (String, [String]) -> Void,
        onDelete: (() -> Void)? = nil
    ) {
        _isPresented = isPresented
        self.allProjects = allProjects
        self.existingGroup = existingGroup
        self.onSave = onSave
        self.onDelete = onDelete

        // Initialize state
        _groupName = State(initialValue: existingGroup?.name ?? "")
        _selectedProjectIDs = State(initialValue: Set(existingGroup?.projectIDs ?? []))
    }

    // MARK: Internal

    var body: some View {
        NavigationStack {
            self.contentView
                .navigationTitle(self.existingGroup == nil ? "Create Group" : "Edit Group")
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            self.isPresented = false
                        }
                    }

                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            self.onSave(self.groupName, Array(self.selectedProjectIDs))
                            self.isPresented = false
                        }
                        .disabled(!self.canSave)
                    }
                }
        }
    }

    // MARK: Private

    @Binding private var isPresented: Bool
    @State private var groupName: String
    @State private var selectedProjectIDs: Set<String>
    @State private var showingDeleteConfirmation = false

    private let allProjects: [Project]
    private let existingGroup: ProjectGroup?
    private let onSave: (String, [String]) -> Void
    private let onDelete: (() -> Void)?

    private var canSave: Bool {
        !self.groupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !self.selectedProjectIDs.isEmpty
    }

    private var contentView: some View {
        VStack(spacing: 0) {
            self.groupNameInput

            Divider()

            self.projectSelectionHeader

            if self.allProjects.isEmpty {
                self.emptyProjectsView
            } else {
                self.projectSelectionList
            }

            Divider()

            if self.onDelete != nil {
                self.deleteButton
            }
        }
    }

    private var groupNameInput: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Group Name")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            TextField("e.g., Work Projects, Personal, etc.", text: self.$groupName)
                .textFieldStyle(.roundedBorder)
        }
        .padding()
    }

    private var projectSelectionHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Select Projects")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                Text("\(self.selectedProjectIDs.count) selected")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            .padding(.top)
        }
    }

    private var deleteButton: some View {
        Button(role: .destructive) {
            self.showingDeleteConfirmation = true
        } label: {
            Label("Delete Group", systemImage: "trash")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .padding()
        .confirmationDialog(
            "Delete this group?",
            isPresented: self.$showingDeleteConfirmation
        ) {
            Button("Delete", role: .destructive) {
                self.onDelete?()
                self.isPresented = false
            }

            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This action cannot be undone.")
        }
    }

    private var emptyProjectsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "folder.fill")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("No Projects Available")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var projectSelectionList: some View {
        List {
            ForEach(self.allProjects) { project in
                ProjectSelectionRow(
                    project: project,
                    isSelected: self.selectedProjectIDs.contains(project.id)
                ) {
                    self.toggleProjectSelection(project.id)
                }
            }
        }
        .listStyle(.plain)
    }

    private func toggleProjectSelection(_ projectID: String) {
        if self.selectedProjectIDs.contains(projectID) {
            self.selectedProjectIDs.remove(projectID)
        } else {
            self.selectedProjectIDs.insert(projectID)
        }
    }
}

// MARK: - ProjectSelectionRow

/// A row for selecting/deselecting a project
private struct ProjectSelectionRow: View {
    // MARK: Lifecycle

    init(project: Project, isSelected: Bool, onToggle: @escaping () -> Void) {
        self.project = project
        self.isSelected = isSelected
        self.onToggle = onToggle
    }

    // MARK: Internal

    var body: some View {
        Button {
            self.onToggle()
        } label: {
            HStack(spacing: 12) {
                // Project avatar
                RoundedRectangle(cornerRadius: 8)
                    .fill(self.project.color)
                    .frame(width: 40, height: 40)
                    .overlay {
                        Text(self.project.title.prefix(1).uppercased())
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.white)
                    }

                // Project info
                VStack(alignment: .leading, spacing: 2) {
                    Text(self.project.title)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)

                    if let description = project.description {
                        Text(description)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                // Checkbox
                Image(systemName: self.isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(self.isSelected ? .blue : .secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: Private

    private let project: Project
    private let isSelected: Bool
    private let onToggle: () -> Void
}
