//
// ProjectFilterMenu.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import SwiftUI
import TENEXCore

/// A menu for filtering conversations by project selection
/// Similar to the TUI's sidebar project checkboxes
struct ProjectFilterMenu: View {
    // MARK: Internal

    let projects: [Project]
    let isProjectSelected: (String) -> Bool
    let toggleProject: (String) -> Void
    let clearFilter: () -> Void
    let hasFilter: Bool
    let selectedCount: Int

    var body: some View {
        Menu {
            menuContent
        } label: {
            menuLabel
        }
    }

    // MARK: Private

    @ViewBuilder
    private var menuLabel: some View {
        HStack(spacing: 4) {
            Image(systemName: filterIcon)
            Text(labelText)
        }
    }

    private var filterIcon: String {
        hasFilter ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle"
    }

    private var labelText: String {
        if !hasFilter {
            return "All Projects"
        } else if selectedCount == 1 {
            return "1 Project"
        } else {
            return "\(selectedCount) Projects"
        }
    }

    @ViewBuilder
    private var menuContent: some View {
        // Clear filter option
        Button {
            clearFilter()
        } label: {
            HStack {
                Text("All Projects")
                if !hasFilter {
                    Spacer()
                    Image(systemName: "checkmark")
                }
            }
        }

        Divider()

        // Project list
        ForEach(projects) { project in
            Button {
                toggleProject(project.coordinate)
            } label: {
                HStack(spacing: 8) {
                    Circle()
                        .fill(project.color)
                        .frame(width: 8, height: 8)

                    Text(project.title)

                    Spacer()

                    if isProjectSelected(project.coordinate), hasFilter {
                        Image(systemName: "checkmark")
                    }
                }
            }
        }
    }
}

// MARK: - TimeFilterMenu

/// A menu for filtering conversations by time
struct TimeFilterMenu: View {
    // MARK: Internal

    let currentFilter: TimeFilter
    let setFilter: (TimeFilter) -> Void

    var body: some View {
        Menu {
            ForEach(TimeFilter.allCases) { filter in
                Button {
                    setFilter(filter)
                } label: {
                    HStack {
                        Label(filter.displayName, systemImage: filter.systemImage)

                        if filter == currentFilter {
                            Spacer()
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: currentFilter.systemImage)
                Text(currentFilter.displayName)
            }
        }
    }
}

// MARK: - ConversationsFilterBar

/// A combined filter bar with both project and time filters
struct ConversationsFilterBar: View {
    // MARK: Internal

    let projects: [Project]
    let currentTimeFilter: TimeFilter
    let hasProjectFilter: Bool
    let selectedProjectCount: Int
    let isProjectSelected: (String) -> Bool
    let toggleProject: (String) -> Void
    let clearProjectFilter: () -> Void
    let setTimeFilter: (TimeFilter) -> Void

    var body: some View {
        HStack(spacing: 12) {
            ProjectFilterMenu(
                projects: projects,
                isProjectSelected: isProjectSelected,
                toggleProject: toggleProject,
                clearFilter: clearProjectFilter,
                hasFilter: hasProjectFilter,
                selectedCount: selectedProjectCount
            )
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)

            TimeFilterMenu(
                currentFilter: currentTimeFilter,
                setFilter: setTimeFilter
            )
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}
