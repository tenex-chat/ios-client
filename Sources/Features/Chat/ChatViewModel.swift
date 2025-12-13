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
    ///   - replyTo: Optional parent message for replies
    public func sendMessage(text: String, replyTo: Message? = nil) async {
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

        do {
            // Publish reply using NDK's reply pattern (matches Svelte implementation)
            // This creates a NIP-22 compliant reply to the thread event
            let (event, _) = try await ndk.publishReply(to: threadEvent) { builder in
                // Filter out auto p-tags (like Svelte: reply.tags.filter(tag => tag[0] !== 'p'))
                let filteredTags = builder.tags.filter { $0.first != "p" }

                // Start fresh with filtered tags
                var newBuilder = builder.setTags(filteredTags)

                // Set content
                newBuilder = newBuilder.content(trimmedText, extractImeta: false)

                // Add project reference as 'a' tag (format: 31933:pubkey:d-tag)
                newBuilder = newBuilder.tag(["a", projectRef])

                // If replying to a specific message, add e-tag with 'reply' marker
                if let replyToMessage {
                    // Check if e-tag doesn't already exist for this message
                    let hasETag = newBuilder.tags.contains { $0.first == "e" && $0[safe: 1] == replyToMessage.id }
                    if !hasETag {
                        newBuilder = newBuilder.tag(["e", replyToMessage.id, "", "reply"])
                    }
                    // Add p-tag for the author of the message being replied to
                    let hasReplyAuthorPTag = newBuilder.tags.contains {
                        $0.first == "p" && $0[safe: 1] == replyToMessage.pubkey
                    }
                    if !hasReplyAuthorPTag {
                        newBuilder = newBuilder.tag(["p", replyToMessage.pubkey])
                    }
                }

                return newBuilder
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
}
