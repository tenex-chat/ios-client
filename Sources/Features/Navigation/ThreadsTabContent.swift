//
// ThreadsTabContent.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

#if os(macOS)
import NDKSwiftCore
import os
import SwiftUI
import TENEXCore

// MARK: - ThreadsTabContent

/// Displays threads for a project in a compact column layout
///
/// This view is designed for the multi-project column interface and provides:
/// - Compact row layout optimized for 320pt width
/// - Thread metadata (title, summary, reply count, timestamp)
/// - Opens conversations in drawer via WindowManagerStore (not NavigationLink)
/// - Independent NDK subscription per column (NDK handles dedup)
@MainActor
public struct ThreadsTabContent: View {
    // MARK: Lifecycle

    /// Initialize threads tab content
    /// - Parameters:
    ///   - projectID: The project coordinate string (kind:pubkey:dTag)
    ///   - currentUserPubkey: The current user's pubkey
    public init(projectID: String, currentUserPubkey: String?) {
        self.projectID = projectID
        self.currentUserPubkey = currentUserPubkey
    }

    // MARK: Public

    public var body: some View {
        Group {
            if let viewModel {
                if let errorMessage = viewModel.errorMessage {
                    errorView(message: errorMessage)
                } else if viewModel.threads.isEmpty {
                    emptyView
                } else {
                    threadList(viewModel: viewModel)
                }
            } else if ndk == nil {
                Text("NDK not available")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                loadingView
            }
        }
        .task {
            guard viewModel == nil, let ndk else {
                return
            }
            Logger().info("[ThreadsTabContent] Initializing for projectID: \(projectID)")
            Logger().info("[ThreadsTabContent] currentUserPubkey: \(currentUserPubkey ?? "nil")")
            let vm = ThreadListViewModel(
                ndk: ndk,
                projectID: projectID,
                filtersStore: filtersStore,
                currentUserPubkey: currentUserPubkey
            )
            viewModel = vm
            vm.subscribe()
            Logger().info("[ThreadsTabContent] Subscribed to threads")
        }
    }

    // MARK: Private

    @Environment(\.ndk) private var ndk
    @Environment(WindowManagerStore.self) private var windowManager

    @State private var viewModel: ThreadListViewModel?
    @State private var filtersStore = ThreadFiltersStore()

    private let projectID: String
    private let currentUserPubkey: String?

    // MARK: - Content

    private func errorView(message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.title)
                .foregroundStyle(.red)
            Text("Error Loading Threads")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(message)
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.large)

            Text("Loading threads...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.title)
                .foregroundStyle(.secondary)

            Text("No Threads")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func threadList(viewModel: ThreadListViewModel) -> some View {
        List {
            ForEach(viewModel.threads) { thread in
                CompactThreadRow(thread: thread)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        windowManager.openDrawer(
                            projectID: projectID,
                            threadID: thread.id,
                            title: thread.title
                        )
                    }
            }
        }
        .listStyle(.plain)
    }
}

// MARK: - CompactThreadRow

/// Compact thread row optimized for 320pt column width
private struct CompactThreadRow: View {
    // MARK: Lifecycle

    init(thread: ThreadSummary) {
        self.thread = thread
    }

    // MARK: Internal

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Title
            Text(thread.title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.primary)
                .lineLimit(2)

            // Summary (if available)
            if let summary = thread.summary, !summary.isEmpty {
                Text(summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            // Metadata row
            HStack(spacing: 6) {
                // Reply count
                Label("\(thread.replyCount)", systemImage: "bubble.left.fill")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                Spacer()

                // Timestamp
                Text(thread.createdAt, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: Private

    private let thread: ThreadSummary
}
#endif
