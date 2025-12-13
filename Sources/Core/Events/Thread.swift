//
// Thread.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation
import NDKSwiftCore
import TENEXShared

// MARK: - Thread

/// Represents a TENEX thread (Nostr kind:11)
/// Note: Use TENEXCore.Thread to avoid conflict with Foundation.Thread
public struct Thread: Identifiable, Sendable {
    // MARK: Lifecycle

    /// Initialize a Thread
    /// - Parameters:
    ///   - id: The thread identifier
    ///   - pubkey: The pubkey of the thread author
    ///   - projectId: The project ID this thread belongs to
    ///   - title: The thread title
    ///   - summary: Optional thread summary/preview
    ///   - createdAt: When the thread was created
    ///   - replyCount: Number of replies in the thread
    ///   - phase: Optional phase tag
    public init(
        id: String,
        pubkey: String,
        projectID: String,
        title: String,
        summary: String?,
        createdAt: Date,
        replyCount: Int,
        phase: String?
    ) {
        self.id = id
        self.pubkey = pubkey
        self.projectID = projectID
        self.title = title
        self.summary = summary
        self.createdAt = createdAt
        self.replyCount = replyCount
        self.phase = phase
    }

    // MARK: Public

    /// The thread identifier (from 'd' tag)
    public let id: String

    /// The pubkey of the thread author
    public let pubkey: String

    /// The project ID this thread belongs to
    public let projectID: String

    /// The thread title
    public let title: String

    /// Optional thread summary/preview
    public let summary: String?

    /// When the thread was created
    public let createdAt: Date

    /// Number of replies in the thread
    public let replyCount: Int

    /// Optional phase tag
    public let phase: String?

    /// Create a Thread from a Nostr event
    /// - Parameter event: The NDKEvent (must be kind:11)
    /// - Returns: A Thread instance, or nil if the event is invalid
    public static func from(event: NDKEvent) -> Self? {
        // Verify correct kind
        guard event.kind == 11 else {
            return nil
        }

        // Extract 'd' tag (required)
        guard let dTag = event.tags(withName: "d").first,
              dTag.count > 1,
              !dTag[1].isEmpty
        else {
            return nil
        }
        let threadID = dTag[1]

        // Extract project ID from 'a' tag (required)
        guard let aTag = event.tags(withName: "a").first,
              aTag.count > 1,
              !aTag[1].isEmpty
        else {
            return nil
        }
        let projectID = aTag[1]

        // Extract title from tags (required)
        guard let titleTag = event.tags(withName: "title").first,
              titleTag.count > 1
        else {
            return nil
        }
        let title = titleTag[1]

        // Extract summary from JSON content (optional)
        let summary = parseSummary(from: event.content)

        // Convert timestamp to Date
        let createdAt = Date(timeIntervalSince1970: TimeInterval(event.createdAt))

        // Extract reply count from tags (default to 0)
        let replyCount = extractReplyCount(from: event)

        // Extract optional phase tag
        let phase = event.tags(withName: "phase").first?[safe: 1]

        return Self(
            id: threadID,
            pubkey: event.pubkey,
            projectID: projectID,
            title: title,
            summary: summary,
            createdAt: createdAt,
            replyCount: replyCount,
            phase: phase
        )
    }

    /// Create a filter for fetching threads by project
    /// - Parameter projectId: The project identifier
    /// - Returns: An NDKFilter configured for kind:11 events
    public static func filter(for projectID: String) -> NDKFilter {
        NDKFilter(
            kinds: [11],
            tags: ["a": Set([projectID])]
        )
    }

    // MARK: Private

    // MARK: - Private Helpers

    private static func parseSummary(from content: String) -> String? {
        guard let data = content.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let summary = json["summary"] as? String,
              !summary.isEmpty
        else {
            return nil
        }
        return summary
    }

    private static func extractReplyCount(from event: NDKEvent) -> Int {
        guard let replyCountTag = event.tags(withName: "reply_count").first,
              replyCountTag.count > 1,
              let count = Int(replyCountTag[1])
        else {
            return 0
        }
        return count
    }
}
