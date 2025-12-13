//
// TypingIndicator.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation
import NDKSwiftCore

/// Represents a typing indicator (Nostr kind:24111 for user, kind:24112 for agent)
public struct TypingIndicator: Identifiable, Sendable {
    /// The indicator identifier (event ID)
    public let id: String

    /// The pubkey of the person typing
    public let pubkey: String

    /// The thread ID where typing is occurring
    public let threadID: String

    /// Whether this is a typing (true) or stopped typing (false) indicator
    public let isTyping: Bool

    /// When the indicator was created
    public let createdAt: Date

    /// Whether this is an agent typing (true) or user typing (false)
    public let isAgent: Bool

    /// Create a TypingIndicator from a Nostr event
    /// - Parameter event: The NDKEvent (must be kind:24111 or kind:24112)
    /// - Returns: A TypingIndicator instance, or nil if the event is invalid
    public static func from(event: NDKEvent) -> Self? {
        // Verify correct kind (24111 = user typing, 24112 = agent typing)
        guard event.kind == 24_111 || event.kind == 24_112 else {
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

        // Determine if agent based on kind
        let isAgent = event.kind == 24_112

        // Convert timestamp to Date
        let createdAt = Date(timeIntervalSince1970: TimeInterval(event.createdAt))

        // Always assume typing (presence of event indicates typing)
        let isTyping = true

        return Self(
            id: event.id,
            pubkey: event.pubkey,
            threadID: threadID,
            isTyping: isTyping,
            createdAt: createdAt,
            isAgent: isAgent
        )
    }

    /// Create a filter for fetching typing indicators by thread
    /// - Parameter threadId: The thread identifier
    /// - Returns: An NDKFilter configured for kind:24111 and kind:24112 events
    public static func filter(for threadID: String) -> NDKFilter {
        NDKFilter(
            kinds: [24_111, 24_112],
            tags: ["e": [threadID]]
        )
    }
}
