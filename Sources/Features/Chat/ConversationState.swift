//
// ConversationState.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation
import NDKSwiftCore
import Observation
import TENEXCore

// MARK: - ConversationState

/// Manages the state of a conversation - flat list of all messages.
/// All messages are kind:1, sorted chronologically.
@MainActor
@Observable
public final class ConversationState {
    // MARK: Lifecycle

    /// Creates a new conversation state for a specific root event.
    /// - Parameters:
    ///   - rootEventID: The ID of the root event
    ///   - onAgentMessage: Optional callback when a message arrives
    public init(
        rootEventID: String,
        onAgentMessage: ((Message) -> Void)? = nil
    ) {
        self.rootEventID = rootEventID
        self.onAgentMessage = onAgentMessage
    }

    // MARK: Public

    /// The ID of the root event
    public let rootEventID: String

    /// Callback when a message arrives (for auto-TTS)
    public var onAgentMessage: ((Message) -> Void)?

    /// Messages keyed by event ID (for deduplication)
    public private(set) var messages: [String: Message] = [:]

    /// Flat display list - all messages sorted by time
    public var displayMessages: [Message] {
        messages.values.sorted { $0.createdAt < $1.createdAt }
    }

    /// Process an incoming event and update state accordingly.
    /// - Parameter event: The NDKEvent to process
    public func processEvent(_ event: NDKEvent) {
        // Only process kind:1 messages
        guard event.kind == 1 else {
            return
        }

        let message = Message.from(event: event) ?? Message(
            id: event.id,
            pubkey: event.pubkey,
            threadID: "",
            content: event.content,
            createdAt: Date(timeIntervalSince1970: TimeInterval(event.createdAt)),
            replyTo: event.tagValue("e"),
            kind: UInt16(event.kind)
        )
        messages[event.id] = message

        // Trigger callback for agent messages (for auto-TTS)
        onAgentMessage?(message)
    }

    /// Clear all state.
    public func clear() {
        messages.removeAll()
    }

    /// Add a message directly (e.g., the root thread event)
    /// - Parameter message: The message to add
    public func addMessage(_ message: Message) {
        messages[message.id] = message
    }
}
