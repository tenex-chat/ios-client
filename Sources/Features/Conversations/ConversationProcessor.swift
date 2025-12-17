//
// ConversationProcessor.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation
import NDKSwiftCore

/// Background actor for processing conversation events
/// All heavy work (parsing, sorting, deduplication) happens here
public actor ConversationProcessor {
    // MARK: - Private State

    private let projectCoordinate: String
    private var threadSummaries: [String: ThreadSummary] = [:]
    private var threadEvents: [String: NDKEvent] = [:]
    private var messagesByThread: [String: [ProcessedMessage]] = [:]
    private var processedMessageIDs: Set<String> = []
    /// Last reply time per author per thread (threadID -> authorPubkey -> Date)
    private var lastReplyByThreadAndAuthor: [String: [String: Date]] = [:]

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
        switch event.kind {
        case 11:
            processThreadEvent(event)
        case 513:
            processMetadataEvent(event)
        case 1111, 21_111:
            processMessageEvent(event)
        default:
            break
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
            replyCount: existingReplyCount,
            lastActivity: existingLastActivity,
            createdAt: createdAt
        )

        threadSummaries[event.id] = threadSummary
        threadEvents[event.id] = event
    }

    private func processMetadataEvent(_ event: NDKEvent) {
        guard let eTag = event.tags(withName: "E").first,
              eTag.count > 1
        else {
            return
        }
        let threadID = eTag[1]

        guard let titleTag = event.tags(withName: "title").first,
              titleTag.count > 1
        else {
            return
        }
        let title = titleTag[1]

        let phase = event.tags(withName: "phase").first?[safe: 1]

        let summary = parseSummary(from: event.content)

        guard let existing = threadSummaries[threadID] else {
            return
        }

        threadSummaries[threadID] = ThreadSummary(
            id: existing.id,
            pubkey: existing.pubkey,
            projectCoordinate: existing.projectCoordinate,
            title: title,
            summary: summary ?? existing.summary,
            phase: phase ?? existing.phase,
            replyCount: existing.replyCount,
            lastActivity: existing.lastActivity,
            createdAt: existing.createdAt
        )
    }

    private func processMessageEvent(_ event: NDKEvent) {
        guard !processedMessageIDs.contains(event.id) else {
            return
        }

        guard let eTag = event.tags(withName: "E").first,
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
                replyCount: existing.replyCount + 1,
                lastActivity: max(existing.lastActivity, message.createdAt),
                createdAt: existing.createdAt
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

        return ConversationStoreState(
            threadSummaries: threadSummaries,
            messageCounts: messageCounts,
            sortedThreadIDs: sortedIDs,
            orphanedMessagesByThread: orphaned,
            totalMessageCount: totalMessages,
            projectCoordinate: projectCoordinate,
            snapshotTimestamp: Date(),
            lastReplyByThreadAndAuthor: lastReplyByThreadAndAuthor
        )
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
        messagesByThread = [:]
        processedMessageIDs = []
        lastReplyByThreadAndAuthor = [:]
    }
}
