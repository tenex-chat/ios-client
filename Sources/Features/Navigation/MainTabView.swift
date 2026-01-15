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
    case conversations = 0
    case projects = 1
    case inbox = 2

    var title: String {
        switch self {
        case .conversations:
            "Conversations"
        case .projects:
            "Projects"
        case .inbox:
            "Inbox"
        }
    }

    var icon: String {
        switch self {
        case .conversations:
            "bubble.left.and.bubble.right"
        case .projects:
            "folder"
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
    @State private var selectedTab: Tab = .conversations

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
            NavigationStack {
                ConversationsView()
            }
            .tabItem {
                Label("Conversations", systemImage: "bubble.left.and.bubble.right")
            }
            .tag(Tab.conversations)

            NavigationShell()
                .tabItem {
                    Label("Projects", systemImage: "folder")
                }
                .tag(Tab.projects)

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
        case .conversations:
            ConversationsView()
        case .projects:
            NavigationShell()
        case .inbox:
            InboxView()
        }
    }

    private var segmentedControl: some View {
        AppleMailSegmentedControl(selection: $selectedTab) {
            var content = SegmentedControlContent<Tab>()
            content.segment("Conversations", value: .conversations, icon: "bubble.left.and.bubble.right")
            content.segment("Projects", value: .projects, icon: "folder")
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
