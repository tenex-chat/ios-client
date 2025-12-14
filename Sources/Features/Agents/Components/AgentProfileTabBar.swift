//
// AgentProfileTabBar.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import SwiftUI

// MARK: - AgentProfileTab

/// Tabs available in the agent profile
enum AgentProfileTab: String, CaseIterable {
    case feed = "Feed"
    case settings = "Settings"
}

// MARK: - AgentProfileTabBar

/// Material Design-style tab bar for agent profile
struct AgentProfileTabBar: View {
    // MARK: Lifecycle

    init(selectedTab: Binding<AgentProfileTab>) {
        _selectedTab = selectedTab
    }

    // MARK: Internal

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(AgentProfileTab.allCases, id: \.self) { tab in
                    TabItem(
                        title: tab.rawValue,
                        isSelected: selectedTab == tab
                    ) {
                        selectedTab = tab
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        .frame(height: 48)
    }

    // MARK: Private

    @Binding private var selectedTab: AgentProfileTab
}

// MARK: - TabItem

/// A single tab in the tab bar
private struct TabItem: View {
    // MARK: Lifecycle

    init(
        title: String,
        isSelected: Bool,
        onTap: @escaping () -> Void
    ) {
        self.title = title
        self.isSelected = isSelected
        self.onTap = onTap
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

                Rectangle()
                    .fill(.accentColor)
                    .frame(height: 2)
                    .opacity(isSelected ? 1 : 0)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: Private

    private let title: String
    private let isSelected: Bool
    private let onTap: () -> Void
}
