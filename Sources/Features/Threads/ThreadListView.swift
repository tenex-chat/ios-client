//
// ThreadListView.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import SwiftUI

// Use struct import to avoid conflict with Foundation.Thread
import struct TENEXCore.Thread

// MARK: - ThreadListView

/// View displaying a list of threads for a project
public struct ThreadListView: View {
    // MARK: Lifecycle

    /// Initialize the thread list view
    /// - Parameters:
    ///   - projectId: The project identifier
    ///   - ndk: The NDK instance for fetching threads
    public init(projectID: String, ndk: any NDKSubscribing) {
        _viewModel = State(initialValue: ThreadListViewModel(ndk: ndk, projectID: projectID))
    }

    // MARK: Public

    public var body: some View {
        Group {
            if viewModel.threads.isEmpty {
                emptyView
            } else {
                threadList
            }
        }
        .task {
            await viewModel.loadThreads()
        }
        .refreshable {
            await viewModel.refresh()
        }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") {
                // Error message will be cleared on next load
            }
        } message: {
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
            }
        }
    }

    // MARK: Private

    @State private var viewModel: ThreadListViewModel

    private var threadList: some View {
        List {
            ForEach(viewModel.threads) { thread in
                ThreadRow(thread: thread)
            }
        }
        #if os(iOS)
        .listStyle(.plain)
        #else
        .listStyle(.inset)
        #endif
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
        VStack(alignment: .leading, spacing: 8) {
            // Thread title
            Text(thread.title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.primary)

            // Thread summary (if available)
            if let summary = thread.summary {
                Text(summary)
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            // Thread metadata
            HStack(spacing: 12) {
                // Reply count
                Label("\(thread.replyCount)", systemImage: "bubble.left.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(.tertiary)

                // Phase badge (if available)
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

                // Creation date
                Text(thread.createdAt, style: .relative)
                    .font(.system(size: 13))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 8)
    }

    // MARK: Private

    private let thread: NostrThread
}
