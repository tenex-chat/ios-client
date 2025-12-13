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
/// These events e-tag kind:11 threads to provide title and description
public struct ConversationMetadata: Sendable {
    /// The thread ID this metadata belongs to (from 'e' tag)
    public let threadID: String

    /// The pubkey of the metadata author
    public let pubkey: String

    /// The conversation title (from 'title' tag)
    public let title: String?

    /// The conversation summary/description (from 'summary' tag)
    public let summary: String?

    /// When the metadata was created
    public let createdAt: Date

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

        // Convert timestamp to Date
        let createdAt = Date(timeIntervalSince1970: TimeInterval(event.createdAt))

        return Self(
            threadID: threadID,
            pubkey: event.pubkey,
            title: title,
            summary: summary,
            createdAt: createdAt
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
}
