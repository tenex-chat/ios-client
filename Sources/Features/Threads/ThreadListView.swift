//
// ThreadListView.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import NDKSwiftCore
import SwiftUI
import TENEXCore

// MARK: - ThreadListView

/// View displaying a list of threads for a project
public struct ThreadListView: View {
    // MARK: Lifecycle

    /// Initialize the thread list view
    /// - Parameters:
    ///   - projectID: The project identifier
    ///   - userPubkey: The current user's pubkey (for chat navigation)
    ///   - filtersStore: The filters store for managing thread filters
    public init(projectID: String, userPubkey: String? = nil, filtersStore: ThreadFiltersStore = ThreadFiltersStore()) {
        self.projectID = projectID
        self.userPubkey = userPubkey
        self.filtersStore = filtersStore
    }

    // MARK: Public

    public var body: some View {
        Group {
            if let ndk {
                contentView(ndk: ndk)
            } else {
                Text("NDK not available")
            }
        }
    }

    // MARK: Private

    @Environment(\.ndk) private var ndk
    @State private var viewModel: ThreadListViewModel?

    private let projectID: String
    private let userPubkey: String?
    private let filtersStore: ThreadFiltersStore

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

    @ViewBuilder
    private func contentView(ndk: NDK) -> some View {
        let vm = viewModel ?? ThreadListViewModel(
            ndk: ndk,
            projectID: projectID,
            filtersStore: filtersStore,
            currentUserPubkey: userPubkey
        )

        Group {
            if vm.threads.isEmpty {
                emptyView
            } else {
                threadList(viewModel: vm)
            }
        }
        .task {
            if viewModel == nil {
                viewModel = vm
                vm.subscribe()
            }
        }
        .alert("Error", isPresented: .constant(vm.errorMessage != nil)) {
            Button("OK") {
                // Error message will be cleared on next load
            }
        } message: {
            if let errorMessage = vm.errorMessage {
                Text(errorMessage)
            }
        }
    }

    private func threadList(viewModel: ThreadListViewModel) -> some View {
        List {
            ForEach(viewModel.threads) { thread in
                Group {
                    if let threadEvent = viewModel.threadEvents[thread.id],
                       let userPubkey {
                        NavigationLink {
                            ChatView(
                                threadEvent: threadEvent,
                                projectReference: thread.projectID,
                                currentUserPubkey: userPubkey
                            )
                        } label: {
                            ThreadRow(thread: thread)
                        }
                    } else {
                        ThreadRow(thread: thread)
                    }
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    archiveButton(for: thread, viewModel: viewModel)
                }
            }
        }
        #if os(iOS)
        .listStyle(.plain)
        #else
        .listStyle(.inset)
        #endif
    }

    private func archiveButton(for thread: NostrThread, viewModel: ThreadListViewModel) -> some View {
        Button(role: .destructive) {
            Task { await viewModel.archiveThread(id: thread.id) }
        } label: {
            Label("Archive", systemImage: "archivebox")
        }
        .tint(.orange)
    }
}

// MARK: - ThreadRow

/// Row component displaying a single thread
struct ThreadRow: View {
    // MARK: Lifecycle

    init(thread: NostrThread) {
        self.thread = thread
    }

    // MARK: Internal

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            // Thread title
            Text(thread.title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary)

            // Thread summary (if available)
            if let summary = thread.summary {
                Text(summary)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            // Thread metadata
            HStack(spacing: 8) {
                // Reply count
                Label("\(thread.replyCount)", systemImage: "bubble.left.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)

                // Phase badge (if available)
                if let phase = thread.phase {
                    Text(phase)
                        .font(.system(size: 9, weight: .medium))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.15))
                        .foregroundStyle(.blue)
                        .cornerRadius(3)
                }

                Spacer()

                // Creation date
                Text(thread.createdAt, style: .relative)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 3)
        .contentShape(Rectangle())
        #if os(iOS)
            .hoverEffect(.highlight)
        #endif
            .accessibilityElement(children: .combine)
            .accessibilityLabel(thread.title)
            .accessibilityHint("\(thread.replyCount) replies. \(thread.summary ?? "Open thread")")
    }

    // MARK: Private

    private let thread: NostrThread
}
