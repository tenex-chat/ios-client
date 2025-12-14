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
/// The `displayMessages` computed property merges all sources into a sorted list for display,
/// filtered to show only the root event and its direct replies (not nested replies).
@MainActor
@Observable
public final class ConversationState {
    // MARK: Lifecycle

    /// Creates a new conversation state for a specific root event.
    /// - Parameters:
    ///   - rootEventID: The ID of the root event (kind:11 thread)
    ///   - onAgentMessage: Optional callback when a final agent message arrives
    public init(
        rootEventID: String,
        onAgentMessage: ((Message) -> Void)? = nil
    ) {
        self.rootEventID = rootEventID
        self.onAgentMessage = onAgentMessage
    }

    // MARK: Public

    /// The ID of the root event (kind:11 thread) - used to filter display messages
    public let rootEventID: String

    /// Callback when a final agent message arrives (for auto-TTS)
    public var onAgentMessage: ((Message) -> Void)?

    /// Final messages keyed by event ID (for deduplication)
    public private(set) var messages: [String: Message] = [:]

    /// Active streaming sessions keyed by pubkey (one stream per agent)
    public private(set) var streamingSessions: [String: StreamingSession] = [:]

    /// Typing indicators keyed by pubkey
    public private(set) var typingIndicators: [String: NDKEvent] = [:]

    /// Merged display list: root + direct replies + streaming, sorted by time.
    /// Only shows root and its direct replies (nested replies are hidden behind reply indicators).
    /// Includes computed reply metadata (replyCount, replyAuthorPubkeys) for messages with nested replies.
    public var displayMessages: [Message] {
        // Build reply index: parent ID -> [replies from ALL messages in thread]
        var repliesByParent: [String: [Message]] = [:]
        for message in messages.values {
            if let parentID = message.replyTo {
                repliesByParent[parentID, default: []].append(message)
            }
        }

        var all: [Message] = []

        // Only include messages that should be displayed at this level:
        // - Root message (replyTo == nil)
        // - Direct replies to root (replyTo == rootEventID)
        for message in messages.values {
            let isRoot = message.replyTo == nil
            let isDirectReplyToRoot = message.replyTo == rootEventID

            guard isRoot || isDirectReplyToRoot else {
                continue // Skip nested replies - they're shown via reply indicators
            }

            // For root message: don't show reply count (its replies are displayed inline)
            // For direct replies: show reply count if they have nested replies
            if isRoot {
                all.append(message)
            } else {
                // This is a direct reply to root - check if it has nested replies
                let nestedReplies = repliesByParent[message.id] ?? []
                if nestedReplies.isEmpty {
                    all.append(message)
                } else {
                    // Get unique pubkeys (up to 3) for avatar display
                    let uniquePubkeys = Array(Set(nestedReplies.map(\.pubkey)).prefix(3))
                    all.append(message.with(replyCount: nestedReplies.count, replyAuthorPubkeys: uniquePubkeys))
                }
            }
        }

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

    /// Add a message directly (e.g., the root thread event which isn't returned by subscriptions)
    /// - Parameter message: The message to add
    public func addMessage(_ message: Message) {
        messages[message.id] = message
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
            kind: UInt16(event.kind),
            status: .sent
        )
        messages[event.id] = message

        // Trigger callback for agent messages (for auto-TTS)
        onAgentMessage?(message)

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
            kind: UInt16(session.latestEvent.kind),
            status: nil,
            isStreaming: true
        )
    }
}
