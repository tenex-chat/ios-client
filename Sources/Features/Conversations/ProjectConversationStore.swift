//
// ProjectConversationStore.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation
import NDKSwiftCore
import Observation
import TENEXCore

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

/// Centralized store for all conversation data within a project
/// Single subscription for kinds: [11, 513, 1111, 21111] with #a tag
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
    }

    // MARK: Public

    /// Thread summaries for list display (keyed by thread ID)
    public private(set) var threadSummaries: [String: ThreadSummary] = [:]

    /// Currently active (open) thread ID
    public private(set) var activeThreadID: String?

    /// Messages for the currently active thread
    public private(set) var activeThreadMessages: [Message] = []

    /// The active subscription (nil if not subscribed)
    public private(set) var subscription: NDKSubscription<NDKEvent>?

    /// Thread events for navigation (keyed by thread ID)
    public private(set) var threadEvents: [String: NDKEvent] = [:]

    /// Sorted list of threads (newest first) - cached to avoid O(n log n) on every access
    public private(set) var sortedThreads: [ThreadSummary] = []

    /// All message events (for filtering by activity/needs-response)
    public var allMessages: [NDKEvent] {
        messageEvents.values.flatMap { $0 }
    }

    // MARK: - Event Processing

    /// Process an incoming event and update state accordingly
    /// - Parameter event: The event to process
    public func processEvent(_ event: NDKEvent) {
        switch event.kind {
        case 11:
            processThreadEvent(event)
        case 513:
            processMetadataEvent(event)
        case 1111:
            processMessageEvent(event)
        default:
            break
        }
    }

    // MARK: - Thread Management

    /// Open a thread and load its messages
    /// - Parameter threadID: The thread ID to open
    public func openThread(_ threadID: String) {
        activeThreadID = threadID

        // Load messages for this thread from stored events
        let events = messageEvents[threadID] ?? []
        activeThreadMessages = events
            .compactMap { Message.from(event: $0) }
            .sorted { $0.createdAt < $1.createdAt }
    }

    /// Close the currently active thread
    public func closeThread() {
        activeThreadID = nil
        activeThreadMessages = []
    }

    // MARK: - Subscription Lifecycle

    /// Subscribe to project events
    public func subscribe() {
        let filter = NDKFilter(
            kinds: [11, 513, 1111, 21_111],
            tags: ["a": Set([projectCoordinate])]
        )
        subscription = ndk.subscribe(filter: filter)
    }

    /// Unsubscribe and clear all state
    public func unsubscribe() {
        subscription = nil
        threadSummaries = [:]
        threadEvents = [:]
        sortedThreads = []
        activeThreadID = nil
        activeThreadMessages = []
        messageEvents = [:]
    }

    // MARK: Private

    private let ndk: NDK
    private let projectCoordinate: String

    /// Stored message events keyed by thread ID
    private var messageEvents: [String: [NDKEvent]] = [:]

    /// Update the sorted threads cache
    private func updateSortedThreads() {
        sortedThreads = threadSummaries.values.sorted { $0.createdAt > $1.createdAt }
    }

    private func processThreadEvent(_ event: NDKEvent) {
        // Extract title from tags
        guard let titleTag = event.tags(withName: "title").first,
              titleTag.count > 1
        else {
            return
        }
        let title = titleTag[1]

        // Extract optional phase
        let phase = event.tags(withName: "phase").first?[safe: 1]

        // Extract optional summary from JSON content
        let summary = parseSummary(from: event.content)

        // Convert timestamp to Date
        let createdAt = Date(timeIntervalSince1970: TimeInterval(event.createdAt))

        // Preserve reply count if updating existing thread
        let existingReplyCount = threadSummaries[event.id]?.replyCount ?? 0
        let existingLastActivity = threadSummaries[event.id]?.lastActivity ?? createdAt

        // Create or update thread summary
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
        updateSortedThreads()
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

    private func processMetadataEvent(_ event: NDKEvent) {
        // Get thread ID from E tag
        guard let eTag = event.tags(withName: "E").first,
              eTag.count > 1
        else {
            return
        }
        let threadID = eTag[1]

        // Extract title
        guard let titleTag = event.tags(withName: "title").first,
              titleTag.count > 1
        else {
            return
        }
        let title = titleTag[1]

        // Extract optional phase
        let phase = event.tags(withName: "phase").first?[safe: 1]

        // Extract optional summary
        let summary = event.tags(withName: "summary").first?[safe: 1]

        // Convert timestamp to Date
        let createdAt = Date(timeIntervalSince1970: TimeInterval(event.createdAt))

        // Only update existing threads - don't create orphan summaries without threadEvents
        guard let existing = threadSummaries[threadID] else {
            return
        }

        threadSummaries[threadID] = ThreadSummary(
            id: threadID,
            pubkey: existing.pubkey,
            projectCoordinate: projectCoordinate,
            title: title,
            summary: summary ?? existing.summary,
            phase: phase,
            replyCount: existing.replyCount,
            lastActivity: existing.lastActivity,
            createdAt: existing.createdAt
        )
        updateSortedThreads()
    }

    private func processMessageEvent(_ event: NDKEvent) {
        // Get thread ID from E tag (thread root reference)
        guard let eTag = event.tags(withName: "E").first,
              eTag.count > 1
        else {
            return
        }
        let threadID = eTag[1]

        // Deduplicate: Check if we already have this message
        if let existingMessages = messageEvents[threadID],
           existingMessages.contains(where: { $0.id == event.id }) {
            return
        }

        // Store the message event
        if messageEvents[threadID] == nil {
            messageEvents[threadID] = []
        }
        messageEvents[threadID]?.append(event)

        // Only update thread summary if thread exists
        guard let existing = threadSummaries[threadID] else {
            return
        }

        // Update reply count and last activity
        let messageTime = Date(timeIntervalSince1970: TimeInterval(event.createdAt))
        threadSummaries[threadID] = ThreadSummary(
            id: existing.id,
            pubkey: existing.pubkey,
            projectCoordinate: existing.projectCoordinate,
            title: existing.title,
            summary: existing.summary,
            phase: existing.phase,
            replyCount: existing.replyCount + 1,
            lastActivity: messageTime > existing.lastActivity ? messageTime : existing.lastActivity,
            createdAt: existing.createdAt
        )
    }
}
