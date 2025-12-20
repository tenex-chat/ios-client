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
    @State private var showingArchivedThreads = false

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
            threadRows(viewModel: viewModel)
            archivedThreadsSection(viewModel: viewModel)
        }
        #if os(iOS)
        .listStyle(.plain)
        .refreshable {
            viewModel.restartSubscriptions()
        }
        #else
        .listStyle(.inset)
        #endif
        .sheet(isPresented: $showingArchivedThreads) {
            if let ndk {
                ArchivedThreadsView(
                    viewModel: viewModel,
                    userPubkey: userPubkey,
                    isPresented: $showingArchivedThreads
                )
            }
        }
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

    @ViewBuilder
    private func archivedThreadsSection(viewModel: ThreadListViewModel) -> some View {
        if viewModel.hasArchivedThreads {
            Section {
                archivedThreadsButton(count: viewModel.archivedThreadsCount)
            }
        }
    }

    private func archivedThreadsButton(count: Int) -> some View {
        Button {
            showingArchivedThreads = true
        } label: {
            HStack {
                Image(systemName: "archivebox")
                    .foregroundStyle(.orange)
                Text("Archived Threads")
                    .foregroundStyle(.primary)
                Spacer()
                Text("\(count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(Capsule())
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .buttonStyle(.plain)
    }

    private func archiveButton(for thread: ThreadSummary, viewModel: ThreadListViewModel) -> some View {
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

    init(thread: ThreadSummary) {
        self.thread = thread
    }

    // MARK: Internal

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            // Thread title
            Text(thread.title)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)

            // Thread summary (if available)
            if let summary = thread.summary {
                Text(summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            // Thread metadata
            HStack(spacing: 8) {
                // Reply count
                Label("\(thread.replyCount)", systemImage: "bubble.left.fill")
                    .font(.caption)
                    .foregroundStyle(.tertiary)

                // Phase badge (if available)
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

                // Creation date
                Text(thread.createdAt, style: .relative)
                    .font(.caption)
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

    private let thread: ThreadSummary
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

// MARK: - ArchivedThreadsView

/// View displaying archived threads with unarchive functionality
struct ArchivedThreadsView: View {
    let viewModel: ThreadListViewModel
    let userPubkey: String?
    @Binding var isPresented: Bool

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.archivedThreads.isEmpty {
                    emptyView
                } else {
                    archivedThreadsList
                }
            }
            .navigationTitle("Archived Threads")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        isPresented = false
                    }
                }
            }
        }
    }

    private var emptyView: some View {
        VStack(spacing: 20) {
            Image(systemName: "archivebox")
                .font(.system(size: 60))
                .foregroundStyle(.orange)

            Text("No Archived Threads")
                .font(.title)
                .fontWeight(.semibold)

            Text("Threads you archive will appear here")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var archivedThreadsList: some View {
        List {
            ForEach(viewModel.archivedThreads) { thread in
                Group {
                    if let userPubkey {
                        NavigationLink {
                            ThreadChatDestination(
                                viewModel: viewModel,
                                thread: thread,
                                userPubkey: userPubkey
                            )
                        } label: {
                            ThreadRow(thread: thread)
                        }
                    } else {
                        ThreadRow(thread: thread)
                    }
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    unarchiveButton(for: thread)
                }
            }
        }
        .listStyle(.plain)
    }

    private func unarchiveButton(for thread: ThreadSummary) -> some View {
        Button {
            Task {
                await viewModel.unarchiveThread(id: thread.id)
            }
        } label: {
            Label("Unarchive", systemImage: "tray.and.arrow.up")
        }
        .tint(.blue)
    }
}
