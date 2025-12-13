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

/// Manages the state of a conversation including messages, streaming sessions, and typing indicators.
///
/// Implements the dual storage model from STREAMING.md:
/// - Final messages (kind 1111) keyed by event ID for deduplication
/// - Streaming sessions (kind 21111) keyed by pubkey (one active stream per agent)
/// - Typing indicators keyed by pubkey
///
/// The `displayMessages` computed property merges all sources into a sorted list for display.
@MainActor
@Observable
public final class ConversationState {
    // MARK: Lifecycle

    /// Creates a new empty conversation state.
    public init() {}

    // MARK: Public

    /// Final messages keyed by event ID (for deduplication)
    public private(set) var messages: [String: Message] = [:]

    /// Active streaming sessions keyed by pubkey (one stream per agent)
    public private(set) var streamingSessions: [String: StreamingSession] = [:]

    /// Typing indicators keyed by pubkey
    public private(set) var typingIndicators: [String: NDKEvent] = [:]

    /// Merged display list: final messages + streaming synthetic messages, sorted by time.
    public var displayMessages: [Message] {
        var all: [Message] = []

        // Add final messages
        all.append(contentsOf: messages.values)

        // Add streaming sessions as synthetic messages
        for session in streamingSessions.values {
            let syntheticMessage = createSyntheticMessage(from: session)
            all.append(syntheticMessage)
        }

        // Sort by creation time (oldest first)
        return all.sorted { $0.createdAt < $1.createdAt }
    }

    /// Process an incoming event and update state accordingly.
    /// - Parameter event: The NDKEvent to process
    public func processEvent(_ event: NDKEvent) {
        if event.isFinalMessage {
            handleFinalMessage(event)
        } else if event.isStreamingDelta {
            handleStreamingEvent(event)
        } else if event.isTypingStart {
            typingIndicators[event.pubkey] = event
        } else if event.isTypingStop {
            typingIndicators.removeValue(forKey: event.pubkey)
        }
    }

    /// Clear all state.
    public func clear() {
        messages.removeAll()
        streamingSessions.removeAll()
        typingIndicators.removeAll()
    }

    // MARK: - Optimistic Message Management

    /// Add an optimistic message (for immediate UI feedback before network confirmation)
    /// - Parameter message: The message to add
    public func addOptimisticMessage(_ message: Message) {
        messages[message.id] = message
    }

    /// Update an optimistic message with its final ID after network confirmation
    /// - Parameters:
    ///   - tempId: The temporary ID used for the optimistic message
    ///   - message: The final message with real ID
    public func replaceOptimisticMessage(tempID: String, with message: Message) {
        messages.removeValue(forKey: tempID)
        messages[message.id] = message
    }

    /// Remove a message by ID (e.g., when retrying a failed message)
    /// - Parameter id: The message ID to remove
    public func removeMessage(id: String) {
        messages.removeValue(forKey: id)
    }

    // MARK: Private

    private func handleFinalMessage(_ event: NDKEvent) {
        // Store the message (keyed by ID for deduplication)
        let message = Message.from(event: event) ?? Message(
            id: event.id,
            pubkey: event.pubkey,
            threadID: "",
            content: event.content,
            createdAt: Date(timeIntervalSince1970: TimeInterval(event.createdAt)),
            replyTo: nil,
            status: .sent
        )
        messages[event.id] = message

        // Clear typing indicator immediately
        typingIndicators.removeValue(forKey: event.pubkey)

        // Clear streaming session immediately
        // (Late chunks are already handled by hasFinalized check in handleStreamingEvent)
        streamingSessions.removeValue(forKey: event.pubkey)
    }

    private func handleStreamingEvent(_ event: NDKEvent) {
        // Check if already finalized (match by pubkey + createdAt)
        let hasFinalized = messages.values.contains { message in
            message.pubkey == event.pubkey &&
                Int64(message.createdAt.timeIntervalSince1970) == event.createdAt
        }
        if hasFinalized {
            return // Ignore late chunk
        }

        // Get or create streaming session
        if var session = streamingSessions[event.pubkey] {
            session.addDelta(from: event)
            streamingSessions[event.pubkey] = session
        } else {
            let session = StreamingSession(event: event)
            streamingSessions[event.pubkey] = session
        }
    }

    private func createSyntheticMessage(from session: StreamingSession) -> Message {
        Message(
            id: session.syntheticID,
            pubkey: session.latestEvent.pubkey,
            threadID: "",
            content: session.reconstructedContent,
            createdAt: Date(timeIntervalSince1970: TimeInterval(session.latestEvent.createdAt)),
            replyTo: nil,
            status: nil,
            isStreaming: true
        )
    }
}
