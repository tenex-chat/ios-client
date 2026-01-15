//
// SplitViewProjectDetail.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import NDKSwiftCore
import SwiftUI
import TENEXCore

// MARK: - SplitViewProjectDetail

/// Project detail view adapted for split view content column
/// Note: Conversations tab removed - use main Conversations tab with project filter instead
struct SplitViewProjectDetail: View {
    let project: Project

    @Environment(\.ndk) private var ndk
    @Environment(NDKAuthManager.self) private var authManager

    var body: some View {
        TabView {
            self.docsTab
            self.agentsTab
            self.feedTab
        }
        .navigationTitle(self.project.title)
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private var docsTab: some View {
        DocsTabView(projectID: self.project.coordinate)
            .tabItem {
                Label("Docs", systemImage: "doc.fill")
            }
    }

    private var agentsTab: some View {
        Group {
            if let ndk {
                AgentsTabView(
                    viewModel: AgentsTabViewModel(
                        ndk: ndk,
                        projectID: self.project.coordinate
                    )
                )
            } else {
                Text("NDK not available")
            }
        }
        .tabItem {
            Label("Agents", systemImage: "person.2.fill")
        }
    }

    private var feedTab: some View {
        Group {
            if let ndk {
                FeedTabViewFactory.create(
                    ndk: ndk,
                    projectID: self.project.coordinate
                )
            } else {
                Text("NDK not available")
            }
        }
        .tabItem {
            Label("Feed", systemImage: "list.bullet")
        }
    }
}

// MARK: - SplitViewChatDetail

/// Chat detail view for split view detail column
struct SplitViewChatDetail: View {
    // MARK: Internal

    let projectID: String
    let threadID: String
    let userPubkey: String?

    var body: some View {
        Group {
            if userPubkey == nil {
                ContentUnavailableView(
                    "Not Signed In",
                    systemImage: "person.crop.circle.badge.xmark",
                    description: Text("Sign in to view and send messages")
                )
            } else if let threadEvent, let userPubkey {
                ChatView(
                    threadEvent: threadEvent,
                    projectReference: self.projectID,
                    currentUserPubkey: userPubkey
                )
            } else {
                ContentUnavailableView(
                    "Thread Not Found",
                    systemImage: "message.badge.questionmark",
                    description: Text("This thread may not exist or hasn't loaded yet")
                )
            }
        }
        .task(id: self.threadID) {
            await self.fetchThreadEvent()
        }
    }

    // MARK: Private

    @Environment(\.ndk) private var ndk
    @State private var threadEvent: NDKEvent?

    private func fetchThreadEvent() async {
        threadEvent = nil

        guard let ndk else {
            return
        }
        let filter = NDKFilter(ids: [threadID])
        let events = await ndk.fetchEvents(filter: filter, timeout: 5.0)
        threadEvent = events.first
    }
}
