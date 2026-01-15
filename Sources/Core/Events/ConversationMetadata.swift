//
// ConversationMetadata.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation
import NDKSwiftCore
import TENEXShared

// MARK: - ConversationMetadata

/// Represents conversation metadata (Nostr kind:513)
/// These events e-tag kind:1 threads to provide title and description
public struct ConversationMetadata: Sendable, Identifiable {
    /// The thread ID this metadata belongs to (from 'e' tag)
    public let threadID: String

    /// The pubkey of the metadata author
    public let pubkey: String

    /// The conversation title (from 'title' tag)
    public let title: String?

    /// The conversation summary/description (from 'summary' tag)
    public let summary: String?

    /// The status label (from 'status-label' tag) - e.g., "In Progress", "Completed"
    public let statusLabel: String?

    /// The current activity description (from 'status-current-activity' tag)
    /// e.g., "Writing integration tests..."
    public let statusCurrentActivity: String?

    /// Tags associated with this conversation (from 't' tags)
    public let tags: [String]

    /// Project coordinate reference (from 'a' tag)
    public let projectCoordinate: String?

    /// When the metadata was created
    public let createdAt: Date

    /// The underlying NDKEvent for navigation purposes
    public let event: NDKEvent?

    // MARK: Lifecycle

    /// Public initializer for creating ConversationMetadata
    public init(
        threadID: String,
        pubkey: String,
        title: String?,
        summary: String?,
        statusLabel: String?,
        statusCurrentActivity: String?,
        tags: [String],
        projectCoordinate: String?,
        createdAt: Date,
        event: NDKEvent?
    ) {
        self.threadID = threadID
        self.pubkey = pubkey
        self.title = title
        self.summary = summary
        self.statusLabel = statusLabel
        self.statusCurrentActivity = statusCurrentActivity
        self.tags = tags
        self.projectCoordinate = projectCoordinate
        self.createdAt = createdAt
        self.event = event
    }

    // MARK: Public

    /// Identifiable conformance using threadID
    public var id: String { threadID }

    /// Whether this conversation has active status (is currently working)
    public var hasActivity: Bool {
        guard let activity = statusCurrentActivity else {
            return false
        }
        return !activity.isEmpty
    }

    /// Create ConversationMetadata from a Nostr event
    /// - Parameter event: The NDKEvent (must be kind:513)
    /// - Returns: A ConversationMetadata instance, or nil if the event is invalid
    public static func from(event: NDKEvent) -> Self? {
        // Verify correct kind
        guard event.kind == 513 else {
            return nil
        }

        // Extract thread ID from 'e' tag (required)
        guard let eTag = event.tags(withName: "e").first,
              eTag.count > 1,
              !eTag[1].isEmpty
        else {
            return nil
        }
        let threadID = eTag[1]

        // Extract optional title from 'title' tag
        let title = event.tags(withName: "title").first?[safe: 1]

        // Extract optional summary from 'summary' tag
        let summary = event.tags(withName: "summary").first?[safe: 1]

        // Extract status fields
        let statusLabel = event.tags(withName: "status-label").first?[safe: 1]
        let statusCurrentActivity = event.tags(withName: "status-current-activity").first?[safe: 1]

        // Extract tags (t tags)
        let tags = event.tags(withName: "t").compactMap { $0[safe: 1] }

        // Extract project coordinate (a tag)
        let projectCoordinate = event.tags(withName: "a").first?[safe: 1]

        // Convert timestamp to Date
        let createdAt = Date(timeIntervalSince1970: TimeInterval(event.createdAt))

        return Self(
            threadID: threadID,
            pubkey: event.pubkey,
            title: title,
            summary: summary,
            statusLabel: statusLabel,
            statusCurrentActivity: statusCurrentActivity,
            tags: tags,
            projectCoordinate: projectCoordinate,
            createdAt: createdAt,
            event: event
        )
    }

    /// Create a filter for fetching conversation metadata by thread
    /// - Parameter threadId: The thread identifier
    /// - Returns: An NDKFilter configured for kind:513 events
    public static func filter(for threadID: String) -> NDKFilter {
        NDKFilter(
            kinds: [513],
            tags: ["e": [threadID]]
        )
    }

    /// Create a filter for fetching all conversation metadata (for Status feed)
    /// - Returns: An NDKFilter configured for all kind:513 events
    public static func allFilter() -> NDKFilter {
        NDKFilter(kinds: [513])
    }
}
