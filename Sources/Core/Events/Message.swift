//
// Message.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation
import NDKSwiftCore

// MARK: - Message

/// Represents a TENEX message (Nostr kind:1111 - GenericReply)
public struct Message: Identifiable, Sendable {
    // MARK: Lifecycle

    /// Initialize a Message
    /// - Parameters:
    ///   - id: The message identifier
    ///   - pubkey: The pubkey of the message author
    ///   - threadId: The thread ID this message belongs to
    ///   - content: The message content
    ///   - createdAt: When the message was created
    ///   - replyTo: Optional parent message ID
    ///   - status: The status of the message
    public init(
        id: String,
        pubkey: String,
        threadID: String,
        content: String,
        createdAt: Date,
        replyTo: String?,
        status: MessageStatus? = nil
    ) {
        self.id = id
        self.pubkey = pubkey
        self.threadID = threadID
        self.content = content
        self.createdAt = createdAt
        self.replyTo = replyTo
        self.status = status
    }

    // MARK: Public

    /// The message identifier (event ID or temporary ID for optimistic messages)
    public let id: String

    /// The pubkey of the message author
    public let pubkey: String

    /// The thread ID this message belongs to
    public let threadID: String

    /// The message content (raw markdown)
    public let content: String

    /// When the message was created
    public let createdAt: Date

    /// Optional parent message ID (from 'e' tag for threading)
    public let replyTo: String?

    /// The status of the message (for optimistic UI updates)
    public let status: MessageStatus?

    /// Create a Message from a Nostr event
    /// - Parameter event: The NDKEvent (must be kind:1111)
    /// - Returns: A Message instance, or nil if the event is invalid
    public static func from(event: NDKEvent) -> Self? {
        // Verify correct kind
        guard event.kind == 1111 // swiftlint:disable:this number_separator else {
            return nil
        }

        // Extract thread ID from 'a' tag (required)
        guard let aTag = event.tags(withName: "a").first,
              aTag.count > 1,
              !aTag[1].isEmpty
        else {
            return nil
        }
        let threadID = aTag[1]

        // Extract optional parent message ID from 'e' tag
        let replyTo = event.tags(withName: "e").first?[safe: 1]

        // Convert timestamp to Date
        let createdAt = Date(timeIntervalSince1970: TimeInterval(event.createdAt))

        return Self(
            id: event.id ?? "",
            pubkey: event.pubkey,
            threadID: threadID,
            content: event.content,
            createdAt: createdAt,
            replyTo: replyTo,
            status: nil
        )
    }

    /// Create a filter for fetching messages by thread
    /// - Parameter threadId: The thread identifier
    /// - Returns: An NDKFilter configured for kind:1111 events
    public static func filter(for threadID: String) -> NDKFilter {
        NDKFilter(
            kinds: [1111] // swiftlint:disable:this number_separator,
            tags: ["a": [threadID]]
        )
    }

    /// Create a copy of this message with a new status
    /// - Parameter status: The new status
    /// - Returns: A new Message with the updated status
    public func with(status: MessageStatus?) -> Self {
        Self(
            id: id,
            pubkey: pubkey,
            threadID: threadID,
            content: content,
            createdAt: createdAt,
            replyTo: replyTo,
            status: status
        )
    }

    /// Create a copy of this message with a new ID
    /// - Parameter id: The new ID
    /// - Returns: A new Message with the updated ID
    public func with(id: String) -> Self {
        Self(
            id: id,
            pubkey: pubkey,
            threadID: threadID,
            content: content,
            createdAt: createdAt,
            replyTo: replyTo,
            status: status
        )
    }
}

// MARK: - Safe Array Access

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
