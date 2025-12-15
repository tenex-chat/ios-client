//
// MainTabView.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import SwiftUI
import TENEXCore

public struct MainTabView: View {
    // MARK: Lifecycle

    public init() {}

    // MARK: Public

    // MARK: - Body

    public var body: some View {
        TabView {
            // Projects Tab - keeps existing NavigationShell (split view on iPad)
            NavigationShell()
                .tabItem {
                    Label("Projects", systemImage: "folder")
                }
                .tag(0)

            // Recent Conversations Tab - simple NavigationStack
            NavigationStack {
                RecentConversationsView()
            }
            .tabItem {
                Label("Recent", systemImage: "bubble.left.and.bubble.right")
            }
            .tag(1)

            // Inbox Tab - simple NavigationStack with badge
            NavigationStack {
                InboxView()
            }
            .tabItem {
                Label("Inbox", systemImage: "tray")
            }
            .badge(self.dataStore.inboxUnreadCount)
            .tag(2)
        }
    }

    // MARK: Private

    // MARK: - Environment

    @Environment(DataStore.self) private var dataStore
}
