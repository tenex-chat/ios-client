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
    /// - Parameter projectID: The project identifier
    public init(projectID: String) {
        self.projectID = projectID
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
        let vm = viewModel ?? ThreadListViewModel(ndk: ndk, projectID: projectID)

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
            }
            await vm.loadThreads()
        }
        .refreshable {
            await vm.refresh()
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
                ThreadRow(thread: thread)
            }
        }
        #if os(iOS)
        .listStyle(.plain)
        #else
        .listStyle(.inset)
        #endif
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
