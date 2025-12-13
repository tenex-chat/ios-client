//
// StreamingDelta.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation
import NDKSwiftCore

/// Represents a streaming delta chunk (Nostr kind:21111)
/// These events accumulate to form the final message content
public struct StreamingDelta: Identifiable, Sendable {
    /// The delta identifier (event ID)
    public let id: String

    /// The pubkey of the delta author
    public let pubkey: String

    /// The message ID this delta belongs to
    public let messageID: String

    /// The text chunk to append
    public let delta: String

    /// When the delta was created
    public let createdAt: Date

    /// Create a StreamingDelta from a Nostr event
    /// - Parameter event: The NDKEvent (must be kind:21111)
    /// - Returns: A StreamingDelta instance, or nil if the event is invalid
    public static func from(event: NDKEvent) -> Self? {
        // Verify correct kind
        guard event.kind == 21_111 else {
            return nil
        }

        // Extract message ID from 'e' tag (required)
        guard let eTag = event.tags(withName: "e").first,
              eTag.count > 1,
              !eTag[1].isEmpty
        else {
            return nil
        }
        let messageID = eTag[1]

        // Convert timestamp to Date
        let createdAt = Date(timeIntervalSince1970: TimeInterval(event.createdAt))

        return Self(
            id: event.id,
            pubkey: event.pubkey,
            messageID: messageID,
            delta: event.content,
            createdAt: createdAt
        )
    }

    /// Create a filter for fetching streaming deltas by message
    /// - Parameter messageId: The message identifier
    /// - Returns: An NDKFilter configured for kind:21111 events
    public static func filter(for messageID: String) -> NDKFilter {
        NDKFilter(
            kinds: [21_111],
            tags: ["e": [messageID]]
        )
    }
}
