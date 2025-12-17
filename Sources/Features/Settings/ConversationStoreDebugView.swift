//
// ConversationStoreDebugView.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import NDKSwiftCore
import SwiftUI
import TENEXCore
import TENEXShared

// MARK: - ConversationStoreDebugSelector

/// Project selector for viewing conversation store debug info
struct ConversationStoreDebugSelector: View {
    @Environment(\.ndk) private var ndk
    @Environment(DataStore.self) private var dataStore

    var body: some View {
        List {
            if dataStore.projects.isEmpty {
                Text("No projects available")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(dataStore.projects) { project in
                    NavigationLink {
                        if let ndk {
                            ConversationStoreDebugViewWrapper(
                                ndk: ndk,
                                projectID: project.coordinate,
                                projectTitle: project.title
                            )
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(project.title)
                                .font(.body)
                            Text(project.coordinate)
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
        .navigationTitle("Select Project")
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

// MARK: - ConversationStoreDebugViewWrapper

/// Wrapper that creates and manages a ProjectConversationStore for debugging
private struct ConversationStoreDebugViewWrapper: View {
    let ndk: NDK
    let projectID: String
    let projectTitle: String

    @State private var store: ProjectConversationStore?
    @State private var subscriptionTask: Task<Void, Never>?

    var body: some View {
        Group {
            if let store {
                ConversationStoreDebugView(store: store)
            } else {
                ProgressView("Loading...")
            }
        }
        .navigationTitle(projectTitle)
        .task {
            let newStore = ProjectConversationStore(ndk: ndk, projectCoordinate: projectID)
            newStore.subscribe()
            store = newStore
        }
        .onDisappear {
            subscriptionTask?.cancel()
        }
    }
}

// MARK: - ConversationStoreDebugView

/// Debug view showing ProjectConversationStore statistics
struct ConversationStoreDebugView: View {
    // MARK: Lifecycle

    init(store: ProjectConversationStore) {
        self.store = store
    }

    // MARK: Internal

    var body: some View {
        List {
            summarySection
            subscriptionSection
            threadsSection
            messagesSection
            orphanedMessagesSection
        }
        .navigationTitle("Conversation Store")
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    // MARK: Private

    private let store: ProjectConversationStore

    private var stats: ConversationStoreDebugStats {
        store.debugStats
    }

    @ViewBuilder
    private var summarySection: some View {
        Section("Summary") {
            StatRow(label: "Project", value: truncatedCoordinate)
            StatRow(label: "Threads", value: "\(stats.threadCount)")
            StatRow(label: "Total Messages", value: "\(stats.totalMessageCount)")
            StatRow(label: "Threads with Messages", value: "\(stats.threadsWithMessages)")

            if stats.orphanedMessageCount > 0 {
                StatRow(label: "Orphaned Messages", value: "\(stats.orphanedMessageCount)")
                    .foregroundStyle(.orange)
            }
        }
    }

    @ViewBuilder
    private var subscriptionSection: some View {
        Section("Subscription") {
            HStack {
                Text("Status")
                Spacer()
                HStack(spacing: 6) {
                    Circle()
                        .fill(stats.subscriptionActive ? Color.green : Color.red)
                        .frame(width: 8, height: 8)
                    Text(stats.subscriptionActive ? "Active" : "Inactive")
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(stats.subscriptionActive ? .green : .red)
                }
            }

            if let activeThread = stats.activeThreadID {
                StatRow(label: "Active Thread", value: String(activeThread.prefix(12)) + "...")
                StatRow(label: "Active Thread Messages", value: "\(stats.activeThreadMessageCount)")
            }

            StatRow(label: "Thread Events Cached", value: "\(stats.threadEventCount)")
        }
    }

    @ViewBuilder
    private var threadsSection: some View {
        Section("Threads") {
            if let oldest = stats.oldestThread {
                LabeledContent("Oldest Thread") {
                    Text(FormattingUtilities.relative(oldest))
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }

            if let newest = stats.newestThread {
                LabeledContent("Newest Thread") {
                    Text(FormattingUtilities.relative(newest))
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }

            if let lastActivity = stats.lastActivityOverall {
                LabeledContent("Last Activity") {
                    Text(FormattingUtilities.relative(lastActivity))
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private var messagesSection: some View {
        Section("Messages per Thread") {
            if stats.messagesPerThread.isEmpty {
                Text("No messages")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(sortedThreadMessages, id: \.threadID) { item in
                    ThreadMessageRow(
                        threadID: item.threadID,
                        messageCount: item.count,
                        threadTitle: store.threadSummaries[item.threadID]?.title
                    )
                }
            }
        }
    }

    @ViewBuilder
    private var orphanedMessagesSection: some View {
        if !stats.orphanedMessagesByThread.isEmpty {
            Section("Orphaned Messages") {
                Text("Messages referencing non-existent threads")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ForEach(sortedOrphanedMessages, id: \.threadID) { item in
                    OrphanedMessageRow(threadID: item.threadID, messageCount: item.count)
                }
            }
        }
    }

    private var sortedOrphanedMessages: [(threadID: String, count: Int)] {
        stats.orphanedMessagesByThread
            .map { (threadID: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
    }

    private var truncatedCoordinate: String {
        let parts = stats.projectCoordinate.split(separator: ":")
        guard parts.count >= 3 else {
            return stats.projectCoordinate
        }
        let pubkey = String(parts[1])
        let truncatedPubkey = String(pubkey.prefix(8)) + "..." + String(pubkey.suffix(4))
        return "\(parts[0]):\(truncatedPubkey):\(parts[2])"
    }

    private var sortedThreadMessages: [(threadID: String, count: Int)] {
        stats.messagesPerThread
            .map { (threadID: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
    }
}

// MARK: - StatRow

private struct StatRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - ThreadMessageRow

private struct ThreadMessageRow: View {
    let threadID: String
    let messageCount: Int
    let threadTitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let title = threadTitle {
                Text(title)
                    .font(.body)
                    .lineLimit(1)
            }

            HStack {
                Text(String(threadID.prefix(16)) + "...")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)

                Spacer()

                Text("\(messageCount) messages")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - OrphanedMessageRow

private struct OrphanedMessageRow: View {
    let threadID: String
    let messageCount: Int

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Thread ID:")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Text(threadID)
                    .font(.caption)
                    .fontDesign(.monospaced)
                    .foregroundStyle(.orange)
                    .lineLimit(1)
            }

            Spacer()

            Text("\(messageCount)")
                .font(.body.monospacedDigit())
                .foregroundStyle(.orange)
        }
        .padding(.vertical, 4)
    }
}
