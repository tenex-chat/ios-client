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
            contentView
                .navigationTitle(existingGroup == nil ? "Create Group" : "Edit Group")
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            isPresented = false
                        }
                    }

                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            onSave(groupName, Array(selectedProjectIDs))
                            isPresented = false
                        }
                        .disabled(!canSave)
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
        !groupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !selectedProjectIDs.isEmpty
    }

    private var contentView: some View {
        VStack(spacing: 0) {
            groupNameInput

            Divider()

            projectSelectionHeader

            if allProjects.isEmpty {
                emptyProjectsView
            } else {
                projectSelectionList
            }

            Divider()

            if onDelete != nil {
                deleteButton
            }
        }
    }

    private var groupNameInput: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Group Name")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            TextField("e.g., Work Projects, Personal, etc.", text: $groupName)
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

                Text("\(selectedProjectIDs.count) selected")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            .padding(.top)
        }
    }

    private var deleteButton: some View {
        Button(role: .destructive) {
            showingDeleteConfirmation = true
        } label: {
            Label("Delete Group", systemImage: "trash")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .padding()
        .confirmationDialog(
            "Delete this group?",
            isPresented: $showingDeleteConfirmation
        ) {
            Button("Delete", role: .destructive) {
                onDelete?()
                isPresented = false
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
            ForEach(allProjects) { project in
                ProjectSelectionRow(
                    project: project,
                    isSelected: selectedProjectIDs.contains(project.id)
                ) {
                    toggleProjectSelection(project.id)
                }
            }
        }
        .listStyle(.plain)
    }

    private func toggleProjectSelection(_ projectID: String) {
        if selectedProjectIDs.contains(projectID) {
            selectedProjectIDs.remove(projectID)
        } else {
            selectedProjectIDs.insert(projectID)
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
            onToggle()
        } label: {
            HStack(spacing: 12) {
                // Project avatar
                RoundedRectangle(cornerRadius: 8)
                    .fill(project.color)
                    .frame(width: 40, height: 40)
                    .overlay {
                        Text(project.title.prefix(1).uppercased())
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                    }

                // Project info
                VStack(alignment: .leading, spacing: 2) {
                    Text(project.title)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.primary)

                    if let description = project.description {
                        Text(description)
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                // Checkbox
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(isSelected ? .blue : .secondary)
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
