//
// ProjectGroupTabBar.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import SwiftUI
import TENEXCore

// MARK: - ProjectGroupTabBar

/// Material Design-style tab bar for project groups
struct ProjectGroupTabBar: View {
    // MARK: Lifecycle

    init(
        selectedGroupID: Binding<String?>,
        groups: [ProjectGroup],
        onCreateGroup: @escaping () -> Void,
        onEditGroup: @escaping (ProjectGroup) -> Void,
        onDeleteGroup: @escaping (ProjectGroup) -> Void
    ) {
        _selectedGroupID = selectedGroupID
        self.groups = groups
        self.onCreateGroup = onCreateGroup
        self.onEditGroup = onEditGroup
        self.onDeleteGroup = onDeleteGroup
    }

    // MARK: Internal

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                // "All Projects" tab
                TabItem(
                    title: "All Projects",
                    isSelected: selectedGroupID == nil,
                    color: nil
                ) {
                    selectedGroupID = nil
                }

                // Group tabs
                ForEach(groups) { group in
                    TabItem(
                        title: group.name,
                        isSelected: selectedGroupID == group.id,
                        color: group.color,
                        onTap: { selectedGroupID = group.id },
                        onLongPress: { showContextMenu(for: group) }
                    )
                }

                // Create group tab
                CreateTabItem(onTap: onCreateGroup)
            }
            .padding(.horizontal, 16)
        }
        .frame(height: 48)
        .confirmationDialog(
            "Manage Group",
            isPresented: $showingContextMenu,
            presenting: contextMenuGroup
        ) { group in
            Button("Edit Group") {
                onEditGroup(group)
            }

            Button("Delete Group", role: .destructive) {
                groupToDelete = group
                showingDeleteAlert = true
            }

            Button("Cancel", role: .cancel) {}
        }
        .alert("Delete Group?", isPresented: $showingDeleteAlert, presenting: groupToDelete) { group in
            Button("Cancel", role: .cancel) {}

            Button("Delete", role: .destructive) {
                onDeleteGroup(group)
            }
        } message: { group in
            Text("Are you sure you want to delete '\(group.name)'? This cannot be undone.")
        }
    }

    // MARK: Private

    @Binding private var selectedGroupID: String?
    @State private var showingContextMenu = false
    @State private var contextMenuGroup: ProjectGroup?
    @State private var showingDeleteAlert = false
    @State private var groupToDelete: ProjectGroup?

    private let groups: [ProjectGroup]
    private let onCreateGroup: () -> Void
    private let onEditGroup: (ProjectGroup) -> Void
    private let onDeleteGroup: (ProjectGroup) -> Void

    private func showContextMenu(for group: ProjectGroup) {
        contextMenuGroup = group
        showingContextMenu = true
    }
}

// MARK: - TabItem

/// A single tab in the tab bar
private struct TabItem: View {
    // MARK: Lifecycle

    init(
        title: String,
        isSelected: Bool,
        color: Color?,
        onTap: @escaping () -> Void,
        onLongPress: (() -> Void)? = nil
    ) {
        self.title = title
        self.isSelected = isSelected
        self.color = color
        self.onTap = onTap
        self.onLongPress = onLongPress
    }

    // MARK: Internal

    var body: some View {
        Button {
            onTap()
        } label: {
            VStack(spacing: 0) {
                Spacer()

                Text(title)
                    .font(.system(size: 14, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(isSelected ? .primary : .secondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)

                // Material Design underline indicator
                Rectangle()
                    .fill(underlineColor)
                    .frame(height: 2)
                    .opacity(isSelected ? 1 : 0)
            }
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.5)
                .onEnded { _ in
                    onLongPress?()
                }
        )
    }

    // MARK: Private

    private let title: String
    private let isSelected: Bool
    private let color: Color?
    private let onTap: () -> Void
    private let onLongPress: (() -> Void)?

    private var underlineColor: Color {
        color ?? .accentColor
    }
}

// MARK: - CreateTabItem

/// The "+" tab for creating new groups
private struct CreateTabItem: View {
    // MARK: Lifecycle

    init(onTap: @escaping () -> Void) {
        self.onTap = onTap
    }

    // MARK: Internal

    var body: some View {
        Button {
            onTap()
        } label: {
            VStack(spacing: 0) {
                Spacer()

                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)

                Rectangle()
                    .fill(.clear)
                    .frame(height: 2)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: Private

    private let onTap: () -> Void
}
