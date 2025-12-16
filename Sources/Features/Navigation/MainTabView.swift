//
// MainTabView.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import SwiftUI
import TENEXCore
import TENEXShared

// MARK: - Tab

private enum Tab: Int, Hashable {
    case projects = 0
    case recent = 1
    case inbox = 2

    var title: String {
        switch self {
        case .projects:
            "Projects"
        case .recent:
            "Recent"
        case .inbox:
            "Inbox"
        }
    }

    var icon: String {
        switch self {
        case .projects:
            "folder"
        case .recent:
            "bubble.left.and.bubble.right"
        case .inbox:
            "tray"
        }
    }
}

public struct MainTabView: View {
    // MARK: Lifecycle

    public init() {}

    // MARK: Public

    public var body: some View {
        #if os(macOS)
        macOSBody
        #else
        iOSBody
        #endif
    }

    // MARK: Private

    @Environment(DataStore.self) private var dataStore
    @State private var selectedTab: Tab = .projects

    #if os(macOS)
    // macOS: Apple Mail-style segmented control in toolbar
    private var macOSBody: some View {
        VStack(spacing: 0) {
            // Top toolbar with segmented control
            HStack {
                segmentedControl
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                Spacer()
            }
            .background {
                Color(nsColor: .windowBackgroundColor)
            }

            Divider()

            // Content area
            contentView
        }
    }
    #endif

    // iOS: Standard TabView with bottom tabs
    private var iOSBody: some View {
        TabView(selection: $selectedTab) {
            NavigationShell()
                .tabItem {
                    Label("Projects", systemImage: "folder")
                }
                .tag(Tab.projects)

            NavigationStack {
                RecentConversationsView()
            }
            .tabItem {
                Label("Recent", systemImage: "clock")
            }
            .tag(Tab.recent)

            NavigationStack {
                InboxView()
            }
            .tabItem {
                Label("Inbox", systemImage: "tray")
            }
            .badge(dataStore.inboxUnreadCount)
            .tag(Tab.inbox)
        }
    }

    @ViewBuilder
    private var contentView: some View {
        switch selectedTab {
        case .projects:
            NavigationShell()
        case .recent:
            RecentConversationsView()
        case .inbox:
            InboxView()
        }
    }

    private var segmentedControl: some View {
        AppleMailSegmentedControl(selection: $selectedTab) {
            var content = SegmentedControlContent<Tab>()
            content.segment("Projects", value: .projects, icon: "folder")
            content.segment("Recent", value: .recent, icon: "clock")
            content.segment(
                "Inbox",
                value: .inbox,
                icon: "tray",
                badge: dataStore.inboxUnreadCount > 0 ? dataStore.inboxUnreadCount : nil
            )
            return content
        }
    }
}
