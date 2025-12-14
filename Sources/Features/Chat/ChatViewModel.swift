//
// ChatViewModel.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation
import NDKSwiftCore
import Observation
import TENEXCore

// MARK: - ChatViewModel

/// View model for the chat screen
@MainActor
@Observable
public final class ChatViewModel {
    // MARK: Lifecycle

    /// Initialize the chat view model
    /// - Parameters:
    ///   - ndk: The NDK instance for fetching and publishing messages
    ///   - threadEvent: The thread event (kind:11) to reply to
    ///   - projectReference: The project reference in format "31933:pubkey:d-tag"
    ///   - userPubkey: The pubkey of the authenticated user
    public init(
        ndk: NDK,
        threadEvent: NDKEvent,
        projectReference: String,
        userPubkey: String
    ) {
        self.ndk = ndk
        self.threadEvent = threadEvent
        self.projectReference = projectReference
        self.userPubkey = userPubkey

        // Add the thread event (kind:11) as the first message
        // Thread events are kind:11, not kind:1111, so we add them directly
        if let threadMessage = Message.from(event: threadEvent) {
            conversationState.addOptimisticMessage(threadMessage)
        }

        // Start continuous subscription in background
        Task {
            await subscribeToAllEvents()
        }
    }

    // MARK: Public

    /// The conversation state managing messages, streaming, and typing
    public let conversationState = ConversationState()

    /// The current error message, if any
    public private(set) var errorMessage: String?

    /// The most recent thread title from kind:513 metadata
    public private(set) var threadTitle: String?

    /// The display messages (final + streaming synthetic), sorted by time
    public var displayMessages: [Message] {
        conversationState.displayMessages
    }

    /// Set of pubkeys of users who are currently typing
    public var typingUsers: Set<String> {
        Set(conversationState.typingIndicators.keys)
    }

    /// The thread ID derived from the thread event
    public var threadID: String {
        threadEvent.id
    }

    /// Subscribe to thread metadata (kind:513) to get the most recent title
    public func subscribeToThreadMetadata() async {
        do {
            // Create filter for metadata for this thread
            let filter = ConversationMetadata.filter(for: threadID)

            let subscription = ndk.subscribeToEvents(filters: [filter])

            var latestMetadata: ConversationMetadata?

            for try await event in subscription {
                // Try to parse as ConversationMetadata
                if let metadata = ConversationMetadata.from(event: event) {
                    // Only use metadata if it's newer than what we already have
                    if let existing = latestMetadata {
                        guard metadata.createdAt > existing.createdAt else {
                            continue
                        }
                    }
                    latestMetadata = metadata
                    threadTitle = metadata.title
                }
            }
        } catch {
            // Silently fail for metadata (non-critical)
        }
    }

    /// Send a new message to the thread
    /// - Parameters:
    ///   - text: The message text
    ///   - targetAgentPubkey: Optional agent pubkey to route message to
    ///   - mentionedPubkeys: Pubkeys of mentioned users to add as p-tags
    ///   - replyTo: Optional parent message for replies
    public func sendMessage(
        text: String,
        targetAgentPubkey: String? = nil,
        mentionedPubkeys: [String] = [],
        replyTo: Message? = nil
    ) async {
        // Validate message text
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            return
        }

        // Create temporary ID for optimistic message
        let tempID = UUID().uuidString

        // Create optimistic message
        let optimisticMessage = Message(
            id: tempID,
            pubkey: userPubkey,
            threadID: projectReference,
            content: trimmedText,
            createdAt: Date(),
            replyTo: replyTo?.id,
            status: .sending
        )

        // Add to conversation state immediately (optimistic update)
        conversationState.addOptimisticMessage(optimisticMessage)

        // Capture values for sendable closure
        let projectRef = projectReference
        let replyToMessage = replyTo
        let agentPubkey = targetAgentPubkey
        let mentions = mentionedPubkeys

        do {
            // Publish reply using NDK's reply pattern (NIP-22 compliant)
            let context = ReplyContext(
                projectRef: projectRef,
                replyTo: replyToMessage,
                agentPubkey: agentPubkey,
                mentions: mentions
            )
            let (event, _) = try await ndk.publishReply(to: threadEvent) { builder in
                buildReplyTags(builder: builder, content: trimmedText, context: context)
            }

            // Update message with sent status and event ID
            let sentMessage = optimisticMessage
                .with(id: event.id)
                .with(status: .sent)
            conversationState.replaceOptimisticMessage(tempID: tempID, with: sentMessage)
        } catch {
            // Update message with failed status
            let failedMessage = optimisticMessage
                .with(status: .failed(error: error.localizedDescription))
            conversationState.replaceOptimisticMessage(tempID: tempID, with: failedMessage)
        }
    }

    /// Retry sending a failed message
    /// - Parameter message: The message to retry
    public func retrySendMessage(_ message: Message) async {
        // Remove the failed message
        conversationState.removeMessage(id: message.id)

        // Send it again
        let parentMessage = message.replyTo.flatMap { replyToID in
            displayMessages.first { $0.id == replyToID }
        }
        await sendMessage(text: message.content, replyTo: parentMessage)
    }

    // MARK: Private

    private let ndk: NDK
    private let threadEvent: NDKEvent
    private let projectReference: String
    private let userPubkey: String

    /// Subscribe to all event types and route through ConversationState
    private func subscribeToAllEvents() async {
        do {
            // Create unified filter for all event types:
            // - kind 1111: final messages
            // - kind 21111: streaming deltas
            // - kind 24111: typing start
            // - kind 24112: typing stop
            // All filtered by the thread's 'e' tag
            let filter = NDKFilter(
                kinds: [1111, 21_111, 24_111, 24_112],
                tags: ["e": Set([threadID])]
            )

            let subscription = ndk.subscribeToEvents(filters: [filter])

            // Continuous subscription - runs forever
            for try await event in subscription {
                conversationState.processEvent(event)
            }
        } catch {
            // Set error message if subscription fails
            errorMessage = "Failed to subscribe to messages."
        }
    }

    /// Build tags for a reply message
    private nonisolated func buildReplyTags(
        builder: NDKEventBuilder,
        content: String,
        context: ReplyContext
    ) -> NDKEventBuilder {
        // Filter out auto p-tags
        let filteredTags = builder.tags.filter { $0.first != "p" }
        var newBuilder = builder.setTags(filteredTags)

        // Set content and project reference
        newBuilder = newBuilder.content(content, extractImeta: false)
        newBuilder = newBuilder.tag(["a", context.projectRef])

        // Add reply tags if replying to a specific message
        if let replyTo = context.replyTo {
            let hasETag = newBuilder.tags.contains { $0.first == "e" && $0[safe: 1] == replyTo.id }
            if !hasETag {
                newBuilder = newBuilder.tag(["e", replyTo.id, "", "reply"])
            }
            let hasReplyAuthorPTag = newBuilder.tags.contains { $0.first == "p" && $0[safe: 1] == replyTo.pubkey }
            if !hasReplyAuthorPTag {
                newBuilder = newBuilder.tag(["p", replyTo.pubkey])
            }
        }

        // Add target agent p-tag for routing
        if let agentPubkey = context.agentPubkey {
            newBuilder = newBuilder.tag(["p", agentPubkey])
        }

        // Add mentioned user p-tags (excluding agent if already added)
        for pubkey in context.mentions where pubkey != context.agentPubkey {
            newBuilder = newBuilder.tag(["p", pubkey])
        }

        return newBuilder
    }
}

// MARK: - ReplyContext

/// Context for building a reply message
private struct ReplyContext: Sendable {
    let projectRef: String
    let replyTo: Message?
    let agentPubkey: String?
    let mentions: [String]
}
