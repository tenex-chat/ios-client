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
                    isSelected: self.selectedGroupID == nil,
                    color: nil
                ) {
                    self.selectedGroupID = nil
                }

                // Group tabs
                ForEach(self.groups) { group in
                    TabItem(
                        title: group.name,
                        isSelected: self.selectedGroupID == group.id,
                        color: group.color,
                        onTap: { self.selectedGroupID = group.id },
                        onLongPress: { self.showContextMenu(for: group) }
                    )
                }

                // Create group tab
                CreateTabItem(onTap: self.onCreateGroup)
            }
            .padding(.horizontal, 16)
        }
        .frame(height: 48)
        .confirmationDialog(
            "Manage Group",
            isPresented: self.$showingContextMenu,
            presenting: self.contextMenuGroup
        ) { group in
            Button("Edit Group") {
                self.onEditGroup(group)
            }

            Button("Delete Group", role: .destructive) {
                self.groupToDelete = group
                self.showingDeleteAlert = true
            }

            Button("Cancel", role: .cancel) {}
        }
        .alert("Delete Group?", isPresented: self.$showingDeleteAlert, presenting: self.groupToDelete) { group in
            Button("Cancel", role: .cancel) {}

            Button("Delete", role: .destructive) {
                self.onDeleteGroup(group)
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
        self.contextMenuGroup = group
        self.showingContextMenu = true
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
            self.onTap()
        } label: {
            VStack(spacing: 0) {
                Spacer()

                Text(self.title)
                    .font(.system(size: 14, weight: self.isSelected ? .semibold : .medium))
                    .foregroundStyle(self.isSelected ? .primary : .secondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)

                // Material Design underline indicator
                Rectangle()
                    .fill(self.underlineColor)
                    .frame(height: 2)
                    .opacity(self.isSelected ? 1 : 0)
            }
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.5)
                .onEnded { _ in
                    self.onLongPress?()
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
        self.color ?? .accentColor
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
            self.onTap()
        } label: {
            VStack(spacing: 0) {
                Spacer()

                Image(systemName: "plus")
                    .font(.subheadline.weight(.medium))
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
