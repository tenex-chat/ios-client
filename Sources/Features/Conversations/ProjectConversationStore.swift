//
// ProjectConversationStore.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation
import NDKSwiftCore
import Observation
import TENEXCore

// MARK: - ConversationStoreDebugStats

/// Debug statistics for ProjectConversationStore
public struct ConversationStoreDebugStats: Sendable {
    /// Number of threads in the store
    public let threadCount: Int
    /// Total number of messages across all threads
    public let totalMessageCount: Int
    /// Message count per thread (threadID -> count)
    public let messagesPerThread: [String: Int]
    /// Number of threads that have at least one message
    public let threadsWithMessages: Int
    /// Number of orphaned messages (messages for threads that don't exist in threadSummaries)
    public let orphanedMessageCount: Int
    /// Orphaned messages by thread ID (threadID -> count) for threads not in threadSummaries
    public let orphanedMessagesByThread: [String: Int]
    /// Oldest thread creation date
    public let oldestThread: Date?
    /// Newest thread creation date
    public let newestThread: Date?
    /// Most recent activity across all threads
    public let lastActivityOverall: Date?
    /// Whether the subscription is active
    public let subscriptionActive: Bool
    /// The project coordinate this store is for
    public let projectCoordinate: String
    /// Number of thread events stored
    public let threadEventCount: Int
    /// Currently active thread ID (if any)
    public let activeThreadID: String?
    /// Number of messages in the active thread
    public let activeThreadMessageCount: Int
}

// MARK: - ThreadSummary

/// Lightweight summary of a thread for list display
public struct ThreadSummary: Identifiable, Sendable {
    /// Thread identifier
    public let id: String
    /// Author pubkey
    public let pubkey: String
    /// Project coordinate
    public let projectCoordinate: String
    /// Thread title
    public let title: String
    /// Optional summary/preview
    public let summary: String?
    /// Optional phase tag
    public let phase: String?
    /// Number of replies in thread
    public var replyCount: Int
    /// Most recent activity timestamp
    public var lastActivity: Date
    /// When the thread was created
    public let createdAt: Date
}

// MARK: - ProjectConversationStore

/// Thin UI layer for conversation state
/// All heavy processing delegated to ConversationProcessor actor
@MainActor
@Observable
public final class ProjectConversationStore {
    // MARK: Lifecycle

    /// Initialize the store for a specific project
    /// - Parameters:
    ///   - ndk: The NDK instance for subscriptions
    ///   - projectCoordinate: The project's addressable coordinate (kind:pubkey:dTag)
    public init(ndk: NDK, projectCoordinate: String) {
        self.ndk = ndk
        self.projectCoordinate = projectCoordinate
        self.processor = ConversationProcessor(projectCoordinate: projectCoordinate)
        self.state = .empty(projectCoordinate: projectCoordinate)
    }

    deinit {
        subscriptionTask?.cancel()
    }

    // MARK: Public

    /// Current state snapshot (immutable)
    public private(set) var state: ConversationStoreState

    /// NDK subscription for monitoring
    public private(set) var subscription: NDKSubscription<NDKEvent>?

    /// Thread summaries (convenience accessor)
    public var threadSummaries: [String: ThreadSummary] {
        state.threadSummaries
    }

    /// Sorted threads by last activity
    public var sortedThreads: [ThreadSummary] {
        state.sortedThreadIDs.compactMap { state.threadSummaries[$0] }
    }

    /// Currently active thread ID
    public private(set) var activeThreadID: String?

    /// Messages for the active thread
    public private(set) var activeThreadMessages: [Message] = []

    /// Debug statistics for developer tools
    public var debugStats: ConversationStoreDebugStats {
        let sortedByCreation = state.threadSummaries.values.sorted { $0.createdAt < $1.createdAt }
        let oldestThread = sortedByCreation.first?.createdAt
        let newestThread = sortedByCreation.last?.createdAt
        let lastActivity = state.threadSummaries.values.map(\.lastActivity).max()
        let threadsWithMessages = state.messageCounts.values.filter { $0 > 0 }.count
        let orphanedCount = state.orphanedMessagesByThread.values.reduce(0, +)

        return ConversationStoreDebugStats(
            threadCount: state.threadSummaries.count,
            totalMessageCount: state.totalMessageCount,
            messagesPerThread: state.messageCounts,
            threadsWithMessages: threadsWithMessages,
            orphanedMessageCount: orphanedCount,
            orphanedMessagesByThread: state.orphanedMessagesByThread,
            oldestThread: oldestThread,
            newestThread: newestThread,
            lastActivityOverall: lastActivity,
            subscriptionActive: subscription != nil,
            projectCoordinate: projectCoordinate,
            threadEventCount: state.threadSummaries.count,
            activeThreadID: activeThreadID,
            activeThreadMessageCount: activeThreadMessages.count
        )
    }

    // MARK: - Subscription Management

    /// Subscribe to project events
    public func subscribe() {
        let filter = NDKFilter(
            kinds: [11, 513, 1111, 21_111],
            tags: ["a": Set([projectCoordinate])]
        )

        let sub = ndk.subscribe(filter: filter)
        subscription = sub

        subscriptionTask = Task { [weak self] in
            for await batch in sub.events {
                guard let self else { break }

                // Process batch in background actor
                let newState = await self.processor.processBatch(batch)

                // Single UI update per batch
                self.state = newState

                // Update active thread messages if needed
                if let activeID = self.activeThreadID {
                    await self.refreshActiveThreadMessages(activeID)
                }
            }
        }
    }

    /// Restart subscriptions and clear state
    public func restartSubscriptions() {
        subscriptionTask?.cancel()
        subscription = nil

        Task {
            await processor.reset()
            state = .empty(projectCoordinate: projectCoordinate)
            subscribe()
        }
    }

    // MARK: - Thread Management

    /// Open a thread and load its messages
    /// - Parameter threadID: The thread ID to open
    public func openThread(_ threadID: String) async {
        activeThreadID = threadID
        await refreshActiveThreadMessages(threadID)
    }

    /// Close the currently active thread
    public func closeThread() {
        activeThreadID = nil
        activeThreadMessages = []
    }

    /// Get thread event for navigation
    public func getThreadEvent(for threadID: String) async -> NDKEvent? {
        await processor.getThreadEvent(for: threadID)
    }

    // MARK: Private

    private let ndk: NDK
    private let projectCoordinate: String
    private let processor: ConversationProcessor
    private nonisolated(unsafe) var subscriptionTask: Task<Void, Never>?

    private func refreshActiveThreadMessages(_ threadID: String) async {
        let processedMessages = await processor.getMessages(for: threadID)
        activeThreadMessages = processedMessages
            .map { Message.from(processed: $0) }
            .sorted { $0.createdAt < $1.createdAt }
    }
}

// MARK: - Message Extension

extension Message {
    /// Create a Message from a ProcessedMessage
    static func from(processed: ProcessedMessage) -> Message {
        Message(
            id: processed.id,
            pubkey: processed.pubkey,
            threadID: processed.threadID,
            content: processed.content,
            createdAt: processed.createdAt,
            replyTo: processed.replyToMessageID,
            kind: 1111
        )
    }
}
