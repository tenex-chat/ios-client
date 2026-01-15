//
// ConversationProcessor.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation
import NDKSwiftCore

/// Background actor for processing conversation events (kind:1 only)
/// All heavy work (parsing, sorting, deduplication) happens here
/// Note: kind:513 metadata is handled centrally by DataStore
public actor ConversationProcessor {
    // MARK: - Private State

    private let projectCoordinate: String
    private var threadSummaries: [String: ThreadSummary] = [:]
    private var threadEvents: [String: NDKEvent] = [:]
    private var messagesByThread: [String: [ProcessedMessage]] = [:]
    private var processedMessageIDs: Set<String> = []
    /// Last reply time per author per thread (threadID -> authorPubkey -> Date)
    private var lastReplyByThreadAndAuthor: [String: [String: Date]] = [:]
    /// All unique hashtags collected from threads
    private var collectedHashtags: Set<String> = []
    /// Parent to children mapping for hierarchy (parentID -> Set of childIDs)
    private var parentToChildren: [String: Set<String>] = [:]

    // MARK: - Initialization

    /// Initialize the processor for a specific project
    /// - Parameter projectCoordinate: The project's addressable coordinate (kind:pubkey:dTag)
    public init(projectCoordinate: String) {
        self.projectCoordinate = projectCoordinate
    }

    // MARK: - Batch Processing

    /// Process a batch of events and return new state snapshot
    public func processBatch(_ events: [NDKEvent]) -> ConversationStoreState {
        for event in events {
            processEvent(event)
        }
        return createSnapshot()
    }

    // MARK: - Event Processing (Private)

    private func processEvent(_ event: NDKEvent) {
        // Only process kind:1 events - metadata (kind:513) is handled by DataStore
        guard event.kind == 1 else {
            return
        }

        // All messages are kind:1 - threads have no e-tags, replies have e-tags
        if event.tags(withName: "e").isEmpty {
            processThreadEvent(event)
        } else {
            processMessageEvent(event)
        }
    }

    private func processThreadEvent(_ event: NDKEvent) {
        guard let titleTag = event.tags(withName: "title").first,
              titleTag.count > 1
        else {
            return
        }
        let title = titleTag[1]
        let phase = event.tags(withName: "phase").first?[safe: 1]
        let summary = parseSummary(from: event.content)

        // Extract hashtags from t-tags
        let hashtags = event.tags(withName: "t").compactMap { tag -> String? in
            guard tag.count > 1, !tag[1].isEmpty else {
                return nil
            }
            return tag[1].lowercased()
        }

        // Add to collected hashtags
        for hashtag in hashtags {
            collectedHashtags.insert(hashtag)
        }

        // Extract parent conversation ID from 'delegation' tag (for thread hierarchy)
        let parentConversationID = event.tags(withName: "delegation").first?[safe: 1]

        // Extract child conversation IDs from 'q' tags (delegated work)
        let childConversationIDs = event.tags(withName: "q").compactMap { $0[safe: 1] }

        // Track parent-child relationships for hierarchy building
        if let parentID = parentConversationID, !parentID.isEmpty {
            parentToChildren[parentID, default: []].insert(event.id)
        }

        let createdAt = Date(timeIntervalSince1970: TimeInterval(event.createdAt))

        let existingMessages = messagesByThread[event.id] ?? []
        let messagesReplyCount = existingMessages.count
        let messagesLastActivity = existingMessages.map(\.createdAt).max()

        let existingReplyCount = threadSummaries[event.id]?.replyCount ?? messagesReplyCount
        let existingLastActivity = threadSummaries[event.id]?.lastActivity
            ?? messagesLastActivity
            ?? createdAt

        let threadSummary = ThreadSummary(
            id: event.id,
            pubkey: event.pubkey,
            projectCoordinate: projectCoordinate,
            title: title,
            summary: summary,
            phase: phase,
            hashtags: hashtags,
            replyCount: existingReplyCount,
            lastActivity: existingLastActivity,
            createdAt: createdAt,
            parentConversationID: parentConversationID,
            childConversationIDs: childConversationIDs
        )

        threadSummaries[event.id] = threadSummary
        threadEvents[event.id] = event
    }

    private func processMessageEvent(_ event: NDKEvent) {
        guard !processedMessageIDs.contains(event.id) else {
            return
        }

        guard let eTag = event.tags(withName: "e").first,
              eTag.count > 1
        else {
            return
        }
        let threadID = eTag[1]

        let replyToID = event.tags(withName: "e").first?[safe: 1]

        let message = ProcessedMessage(
            id: event.id,
            threadID: threadID,
            pubkey: event.pubkey,
            content: event.content,
            createdAt: Date(timeIntervalSince1970: TimeInterval(event.createdAt)),
            replyToMessageID: replyToID
        )

        processedMessageIDs.insert(event.id)

        if messagesByThread[threadID] == nil {
            messagesByThread[threadID] = []
        }
        messagesByThread[threadID]?.append(message)

        // Track last reply time per author for needs-response filtering
        if lastReplyByThreadAndAuthor[threadID] == nil {
            lastReplyByThreadAndAuthor[threadID] = [:]
        }
        if let existingAuthorTime = lastReplyByThreadAndAuthor[threadID]?[event.pubkey] {
            if message.createdAt > existingAuthorTime {
                lastReplyByThreadAndAuthor[threadID]?[event.pubkey] = message.createdAt
            }
        } else {
            lastReplyByThreadAndAuthor[threadID]?[event.pubkey] = message.createdAt
        }

        if var existing = threadSummaries[threadID] {
            existing = ThreadSummary(
                id: existing.id,
                pubkey: existing.pubkey,
                projectCoordinate: existing.projectCoordinate,
                title: existing.title,
                summary: existing.summary,
                phase: existing.phase,
                hashtags: existing.hashtags,
                replyCount: existing.replyCount + 1,
                lastActivity: max(existing.lastActivity, message.createdAt),
                createdAt: existing.createdAt,
                parentConversationID: existing.parentConversationID,
                childConversationIDs: existing.childConversationIDs
            )
            threadSummaries[threadID] = existing
        }
    }

    private func parseSummary(from content: String) -> String? {
        guard let data = content.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let summary = json["summary"] as? String,
              !summary.isEmpty
        else {
            return nil
        }
        return summary
    }

    // MARK: - Snapshot Creation

    private func createSnapshot() -> ConversationStoreState {
        let sortedIDs = threadSummaries.values
            .sorted { $0.lastActivity > $1.lastActivity }
            .map(\.id)

        let messageCounts = messagesByThread.mapValues(\.count)
        let totalMessages = messageCounts.values.reduce(0, +)

        var orphaned: [String: Int] = [:]
        for (threadID, messages) in messagesByThread where threadSummaries[threadID] == nil {
            orphaned[threadID] = messages.count
        }

        // Build hierarchical thread list
        let hierarchicalThreads = buildHierarchicalThreads()

        return ConversationStoreState(
            threadSummaries: threadSummaries,
            messageCounts: messageCounts,
            sortedThreadIDs: sortedIDs,
            orphanedMessagesByThread: orphaned,
            totalMessageCount: totalMessages,
            projectCoordinate: projectCoordinate,
            snapshotTimestamp: Date(),
            lastReplyByThreadAndAuthor: lastReplyByThreadAndAuthor,
            hashtags: Array(collectedHashtags).sorted(),
            hierarchicalThreads: hierarchicalThreads,
            parentToChildren: parentToChildren
        )
    }

    // MARK: - Hierarchy Building

    /// Build hierarchical thread list for tree display
    /// Follows the Svelte/TUI pattern: roots first, then children indented
    private func buildHierarchicalThreads() -> [HierarchicalThread] {
        // Find root threads (no parent or parent not in this project)
        let rootThreads = threadSummaries.values
            .filter { thread in
                guard let parentID = thread.parentConversationID, !parentID.isEmpty else {
                    return true // No parent = root
                }
                // If parent exists in our threads, this is not a root
                return threadSummaries[parentID] == nil
            }
            .sorted { $0.lastActivity > $1.lastActivity }

        var result: [HierarchicalThread] = []

        for (index, rootThread) in rootThreads.enumerated() {
            let isLast = index == rootThreads.count - 1
            buildHierarchyRecursive(
                thread: rootThread,
                depth: 0,
                isLastChild: isLast,
                result: &result
            )
        }

        return result
    }

    /// Recursively build hierarchy tree
    private func buildHierarchyRecursive(
        thread: ThreadSummary,
        depth: Int,
        isLastChild: Bool,
        result: inout [HierarchicalThread]
    ) {
        let childIDs = parentToChildren[thread.id] ?? []
        let children = childIDs.compactMap { threadSummaries[$0] }
            .sorted { $0.lastActivity > $1.lastActivity }

        let childCount = countDescendants(threadID: thread.id)

        let hierarchicalThread = HierarchicalThread(
            thread: thread,
            depth: depth,
            isLastChild: isLastChild,
            hasChildren: !children.isEmpty,
            childCount: childCount
        )

        result.append(hierarchicalThread)

        // Recursively add children (max depth 10 to prevent infinite loops)
        guard depth < 10 else {
            return
        }

        for (index, child) in children.enumerated() {
            let isLast = index == children.count - 1
            buildHierarchyRecursive(
                thread: child,
                depth: depth + 1,
                isLastChild: isLast,
                result: &result
            )
        }
    }

    /// Count total descendants recursively
    private func countDescendants(threadID: String) -> Int {
        let childIDs = parentToChildren[threadID] ?? []
        var count = childIDs.count
        for childID in childIDs {
            count += countDescendants(threadID: childID)
        }
        return count
    }

    // MARK: - Thread Management

    /// Get messages for a specific thread
    public func getMessages(for threadID: String) -> [ProcessedMessage] {
        messagesByThread[threadID] ?? []
    }

    /// Get thread event for navigation
    public func getThreadEvent(for threadID: String) -> NDKEvent? {
        threadEvents[threadID]
    }

    /// Reset all state
    public func reset() {
        threadSummaries = [:]
        threadEvents = [:]
        parentToChildren = [:]
        messagesByThread = [:]
        processedMessageIDs = []
        lastReplyByThreadAndAuthor = [:]
        collectedHashtags = []
    }
}
