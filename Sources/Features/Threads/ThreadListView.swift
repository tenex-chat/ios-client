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
    ///   - showArchived: Binding to control whether archived threads are shown
    public init(
        projectID: String,
        userPubkey: String? = nil,
        filtersStore: ThreadFiltersStore = ThreadFiltersStore(),
        showArchived: Binding<Bool> = .constant(false)
    ) {
        self.projectID = projectID
        self.userPubkey = userPubkey
        self.filtersStore = filtersStore
        self._showArchived = showArchived
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
    @Binding private var showArchived: Bool

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
        .onChange(of: showArchived) { _, newValue in
            vm.showArchived = newValue
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
            threadRows(viewModel: viewModel)
        }
        #if os(iOS)
        .listStyle(.plain)
        .refreshable {
            viewModel.restartSubscriptions()
        }
        #else
        .listStyle(.inset)
        #endif
    }

    @ViewBuilder
    private func threadRows(viewModel: ThreadListViewModel) -> some View {
        ForEach(viewModel.threads) { thread in
            Group {
                if let userPubkey {
                    NavigationLink {
                        ThreadChatDestination(
                            viewModel: viewModel,
                            thread: thread,
                            userPubkey: userPubkey
                        )
                    } label: {
                        ThreadRow(thread: thread, isArchived: viewModel.archivedThreads.contains { $0.id == thread.id })
                    }
                } else {
                    ThreadRow(thread: thread, isArchived: viewModel.archivedThreads.contains { $0.id == thread.id })
                }
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                if viewModel.archivedThreads.contains(where: { $0.id == thread.id }) {
                    unarchiveButton(for: thread, viewModel: viewModel)
                } else {
                    archiveButton(for: thread, viewModel: viewModel)
                }
            }
        }
    }

    private func archiveButton(for thread: ThreadSummary, viewModel: ThreadListViewModel) -> some View {
        Button(role: .destructive) {
            Task { await viewModel.archiveThread(id: thread.id) }
        } label: {
            Label("Archive", systemImage: "archivebox")
        }
        .tint(.orange)
    }

    private func unarchiveButton(for thread: ThreadSummary, viewModel: ThreadListViewModel) -> some View {
        Button {
            Task { await viewModel.unarchiveThread(id: thread.id) }
        } label: {
            Label("Unarchive", systemImage: "tray.and.arrow.up")
        }
        .tint(.blue)
    }
}

// MARK: - ThreadRow

/// Row component displaying a single thread
struct ThreadRow: View {
    // MARK: Lifecycle

    init(thread: ThreadSummary, isArchived: Bool = false) {
        self.thread = thread
        self.isArchived = isArchived
    }

    // MARK: Internal

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            titleView
            summaryView
            metadataView
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

    private var titleView: some View {
        HStack(spacing: 6) {
            if isArchived {
                Image(systemName: "archivebox.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
            Text(thread.title)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
        }
    }

    @ViewBuilder
    private var summaryView: some View {
        if let summary = thread.summary {
            Text(summary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    private var metadataView: some View {
        HStack(spacing: 8) {
            Label("\(thread.replyCount)", systemImage: "bubble.left.fill")
                .font(.caption)
                .foregroundStyle(.tertiary)

            if let phase = thread.phase {
                Text(phase)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.15))
                    .foregroundStyle(.blue)
                    .cornerRadius(3)
            }

            Spacer()

            Text(thread.createdAt, style: .relative)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: Private

    private let thread: ThreadSummary
    private let isArchived: Bool
}

// MARK: - ThreadChatDestination

/// Async destination view that loads thread event before showing ChatView
private struct ThreadChatDestination: View {
    let viewModel: ThreadListViewModel
    let thread: ThreadSummary
    let userPubkey: String

    @State private var threadEvent: NDKEvent?

    var body: some View {
        Group {
            if let threadEvent {
                ChatView(
                    threadEvent: threadEvent,
                    projectReference: thread.projectCoordinate,
                    currentUserPubkey: userPubkey
                )
            } else {
                ProgressView("Loading thread...")
            }
        }
        .task {
            threadEvent = await viewModel.getThreadEvent(for: thread.id)
        }
    }
}
