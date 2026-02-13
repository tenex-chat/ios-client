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
    /// Maintained in sorted order to avoid expensive sorting on every access
    public private(set) var displayMessages: [Message] = []

    /// Whether initial loading is complete (used to defer scroll animations)
    public private(set) var isInitialLoadComplete = false

    /// Mark initial load as complete (call after priming with cached data)
    public func markInitialLoadComplete() {
        isInitialLoadComplete = true
    }

    /// Load multiple messages at once (for priming from cache)
    /// - Parameter newMessages: Array of messages to load
    public func loadMessages(_ newMessages: [Message]) {
        for message in newMessages {
            messages[message.id] = message
        }
        rebuildDisplayMessages()
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

        // Check if this is a new message or an update
        let existingMessage = messages[event.id]
        let isNewMessage = existingMessage == nil

        // Skip if message already exists with same content (duplicate from relay)
        if let existing = existingMessage, existing.content == message.content {
            return
        }

        messages[event.id] = message

        if isNewMessage {
            // Insert in sorted order using binary search
            insertMessageSorted(message)
        } else {
            // Message was updated, rebuild displayMessages from scratch
            rebuildDisplayMessages()
        }

        // Trigger callback for agent messages (for auto-TTS)
        onAgentMessage?(message)
    }

    /// Clear all state.
    public func clear() {
        messages.removeAll()
        displayMessages.removeAll()
    }

    // MARK: Private

    /// Insert a message into displayMessages in sorted order using binary search
    private func insertMessageSorted(_ message: Message) {
        let insertIndex = displayMessages.firstIndex { $0.createdAt > message.createdAt } ?? displayMessages.endIndex
        displayMessages.insert(message, at: insertIndex)
    }

    /// Rebuild displayMessages from messages dictionary
    private func rebuildDisplayMessages() {
        displayMessages = messages.values.sorted { $0.createdAt < $1.createdAt }
    }

    /// Add a message directly (e.g., the root thread event)
    /// - Parameter message: The message to add
    public func addMessage(_ message: Message) {
        let isNewMessage = messages[message.id] == nil
        messages[message.id] = message

        if isNewMessage {
            insertMessageSorted(message)
        } else {
            rebuildDisplayMessages()
        }
    }
}
