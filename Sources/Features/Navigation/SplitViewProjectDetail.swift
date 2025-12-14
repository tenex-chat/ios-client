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
            threadsTab
            docsTab
            agentsTab
            feedTab
        }
        .navigationTitle(project.title)
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private var threadsTab: some View {
        SplitViewThreadList(
            projectID: project.coordinate,
            userPubkey: authManager.activePubkey,
            selectedThreadID: $selectedThreadID
        )
        .tabItem {
            Label("Threads", systemImage: "message.fill")
        }
    }

    private var docsTab: some View {
        DocsTabView(projectID: project.coordinate)
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
                        projectID: project.coordinate
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
        FeedTabView(projectID: project.coordinate)
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
                    threadListContent(viewModel: viewModel)
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
            emptyView
        } else {
            threadList(viewModel: viewModel)
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
        List(viewModel.threads, selection: $selectedThreadID) { thread in
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
    let thread: NostrThread

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(thread.title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.primary)

            if let summary = thread.summary {
                Text(summary)
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            HStack(spacing: 12) {
                Label("\(thread.replyCount)", systemImage: "bubble.left.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(.tertiary)

                if let phase = thread.phase {
                    Text(phase)
                        .font(.system(size: 11, weight: .medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.15))
                        .foregroundStyle(.blue)
                        .cornerRadius(6)
                }

                Spacer()

                Text(thread.createdAt, style: .relative)
                    .font(.system(size: 13))
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
                    projectReference: projectID,
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
        .task(id: threadID) {
            startSubscription()
        }
    }

    // MARK: Private

    @Environment(\.ndk) private var ndk
    @State private var subscription: NDKSubscription<NDKEvent>?

    private func startSubscription() {
        // Cancel previous subscription when threadID changes
        subscription = nil

        guard let ndk else {
            return
        }
        let filter = NDKFilter(ids: [threadID])
        subscription = ndk.subscribe(filter: filter)
    }
}
