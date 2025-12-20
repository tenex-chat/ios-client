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
struct SplitViewProjectDetail: View {
    let project: Project
    @Binding var selectedThreadID: String?

    @Environment(\.ndk) private var ndk
    @Environment(NDKAuthManager.self) private var authManager

    var body: some View {
        TabView {
            self.threadsTab
            self.docsTab
            self.agentsTab
            self.feedTab
        }
        .navigationTitle(self.project.title)
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private var threadsTab: some View {
        SplitViewThreadList(
            projectID: self.project.coordinate,
            userPubkey: self.authManager.activePubkey,
            selectedThreadID: self.$selectedThreadID
        )
        .tabItem {
            Label("Threads", systemImage: "message.fill")
        }
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

// MARK: - SplitViewThreadList

/// Thread list adapted for split view with selection binding
struct SplitViewThreadList: View {
    let projectID: String
    let userPubkey: String?
    @Binding var selectedThreadID: String?

    @Environment(\.ndk) private var ndk
    @State private var viewModel: ThreadListViewModel?
    @State private var filtersStore = ThreadFiltersStore()

    var body: some View {
        Group {
            if let ndk {
                if let viewModel {
                    self.threadListContent(viewModel: viewModel)
                } else {
                    // Show nothing while ViewModel initializes (no loading spinners per PLAN.md)
                    Color.clear
                        .task {
                            let vm = ThreadListViewModel(
                                ndk: ndk,
                                projectID: projectID,
                                filtersStore: filtersStore,
                                currentUserPubkey: userPubkey
                            )
                            viewModel = vm
                            vm.subscribe()
                        }
                }
            } else {
                ContentUnavailableView(
                    "Not Connected",
                    systemImage: "network.slash",
                    description: Text("Unable to connect to Nostr network")
                )
            }
        }
    }

    @ViewBuilder
    private func threadListContent(viewModel: ThreadListViewModel) -> some View {
        if viewModel.threads.isEmpty {
            self.emptyView
        } else {
            self.threadList(viewModel: viewModel)
        }
    }

    private var emptyView: some View {
        VStack(spacing: 20) {
            Image(systemName: "message.fill")
                .font(.system(size: 60))
                .foregroundStyle(.blue)

            Text("No Threads Yet")
                .font(.title)
                .fontWeight(.semibold)

            Text("Start a conversation to create a thread")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private func threadList(viewModel: ThreadListViewModel) -> some View {
        List(viewModel.threads, selection: self.$selectedThreadID) { thread in
            SplitViewThreadRow(thread: thread)
                .tag(thread.id)
        }
        #if os(iOS)
        .listStyle(.plain)
        #else
        .listStyle(.inset)
        #endif
    }
}

// MARK: - SplitViewThreadRow

/// Thread row for split view selection
struct SplitViewThreadRow: View {
    let thread: ThreadSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(self.thread.title)
                .font(.headline)
                .foregroundStyle(.primary)

            if let summary = thread.summary {
                Text(summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            HStack(spacing: 12) {
                Label("\(self.thread.replyCount)", systemImage: "bubble.left.fill")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)

                if let phase = thread.phase {
                    Text(phase)
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.15))
                        .foregroundStyle(.blue)
                        .cornerRadius(6)
                }

                Spacer()

                Text(self.thread.createdAt, style: .relative)
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 8)
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
            } else if let threadEvent = subscription?.data.first, let userPubkey {
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
            self.startSubscription()
        }
    }

    // MARK: Private

    @Environment(\.ndk) private var ndk
    @State private var subscription: NDKSubscription<NDKEvent>?

    private func startSubscription() {
        // Cancel previous subscription when threadID changes
        self.subscription = nil

        guard let ndk else {
            return
        }
        let filter = NDKFilter(ids: [threadID])
        self.subscription = ndk.subscribe(filter: filter)
    }
}
