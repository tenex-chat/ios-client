//
// ConversationStoreState.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation

/// Immutable snapshot of conversation store state for thread-safe UI updates
public struct ConversationStoreState: Sendable {
    /// Thread summaries keyed by thread ID
    public let threadSummaries: [String: ThreadSummary]

    /// Message counts per thread (threadID -> count)
    public let messageCounts: [String: Int]

    /// Pre-computed sorted thread IDs (by last activity, descending)
    public let sortedThreadIDs: [String]

    /// Orphaned message counts (messages for non-existent threads)
    public let orphanedMessagesByThread: [String: Int]

    /// Total message count across all threads
    public let totalMessageCount: Int

    /// Project coordinate this state belongs to
    public let projectCoordinate: String

    /// Timestamp when this snapshot was created
    public let snapshotTimestamp: Date

    /// Last reply time per author per thread (threadID -> authorPubkey -> Date)
    /// Used for "needs response" filtering
    public let lastReplyByThreadAndAuthor: [String: [String: Date]]

    /// Empty state initializer
    public static func empty(projectCoordinate: String) -> Self {
        Self(
            threadSummaries: [:],
            messageCounts: [:],
            sortedThreadIDs: [],
            orphanedMessagesByThread: [:],
            totalMessageCount: 0,
            projectCoordinate: projectCoordinate,
            snapshotTimestamp: Date(),
            lastReplyByThreadAndAuthor: [:]
        )
    }
}
