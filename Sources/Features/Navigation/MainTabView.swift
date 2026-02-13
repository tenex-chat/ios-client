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
    case newThread = 3

    var title: String {
        switch self {
        case .conversations:
            "Conversations"
        case .projects:
            "Projects"
        case .inbox:
            "Inbox"
        case .newThread:
            "New Thread"
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
        case .newThread:
            "plus"
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
    @State private var previousTab: Tab = .conversations
    @State private var showingProjectPicker = false
    private let archiveStorage: ArchiveStorage = UserDefaultsArchiveStorage()

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

    // iOS: Standard TabView with bottom tabs (icons only)
    private var iOSBody: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                ConversationsView()
            }
            .tabItem {
                Image(systemName: "bubble.left.and.bubble.right")
            }
            .tag(Tab.conversations)

            NavigationShell()
                .tabItem {
                    Image(systemName: "folder")
                }
                .tag(Tab.projects)

            NavigationStack {
                InboxView()
            }
            .tabItem {
                Image(systemName: "tray")
            }
            .badge(dataStore.inboxUnreadCount)
            .tag(Tab.inbox)

            Color.clear
                .tabItem {
                    Image(systemName: "plus")
                }
                .tag(Tab.newThread)
        }
        .onChange(of: selectedTab) { _, newValue in
            if newValue == .newThread {
                selectedTab = previousTab
                showingProjectPicker = true
            } else {
                previousTab = newValue
            }
        }
        .sheet(isPresented: $showingProjectPicker) {
            NewThreadProjectPickerSheet(projects: availableProjects)
        }
    }

    private var availableProjects: [Project] {
        let archivedIDs = archiveStorage.archivedProjectIDs()
        return dataStore.projects.filter { !archivedIDs.contains($0.id) }
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
        case .newThread:
            ConversationsView()
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
