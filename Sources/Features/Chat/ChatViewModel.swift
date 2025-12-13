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
        if let threadMessage = Message.from(event: threadEvent) {
            messages.append(threadMessage)
        }

        // Start continuous subscription in background
        Task {
            await subscribeToMessages()
        }
    }

    // MARK: Public

    /// The list of messages
    public private(set) var messages: [Message] = []

    /// The current error message, if any
    public private(set) var errorMessage: String?

    /// Accumulated streaming content by message ID
    public private(set) var streamingContent: [String: String] = [:]

    /// Set of pubkeys of users who are currently typing
    public private(set) var typingUsers: Set<String> = []

    /// The most recent thread title from kind:513 metadata
    public private(set) var threadTitle: String?

    /// The thread ID derived from the thread event
    public var threadID: String {
        threadEvent.id
    }

    /// Subscribe to streaming deltas for real-time message updates
    public func subscribeToStreamingDeltas() async {
        do {
            // Subscribe to all streaming deltas for messages in this thread
            // Messages reference the project via the 'a' tag
            let filter = NDKFilter(
                kinds: [21_111],
                tags: ["a": [projectReference]]
            )

            let subscription = ndk.subscribeToEvents(filters: [filter])

            for try await event in subscription {
                // Try to parse as StreamingDelta
                if let delta = StreamingDelta.from(event: event) {
                    // Accumulate delta content
                    let currentContent = streamingContent[delta.messageID] ?? ""
                    streamingContent[delta.messageID] = currentContent + delta.delta
                }
            }
        } catch {
            // Silently fail for streaming deltas (non-critical)
        }
    }

    /// Subscribe to typing indicators for real-time typing status
    public func subscribeToTypingIndicators() async {
        do {
            // Create filter for typing indicators in this thread
            let filter = TypingIndicator.filter(for: threadID)

            let subscription = ndk.subscribeToEvents(filters: [filter])

            for try await event in subscription {
                // Try to parse as TypingIndicator
                if let indicator = TypingIndicator.from(event: event) {
                    if indicator.isTyping {
                        // Add to typing users
                        typingUsers.insert(indicator.pubkey)
                    } else {
                        // Remove from typing users
                        typingUsers.remove(indicator.pubkey)
                    }
                }
            }
        } catch {
            // Silently fail for typing indicators (non-critical)
        }
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

        // Add to messages immediately (optimistic update)
        messages.append(optimisticMessage)

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
            if let index = messages.firstIndex(where: { $0.id == tempID }) {
                messages[index] = optimisticMessage
                    .with(id: event.id)
                    .with(status: .sent)
            }
        } catch {
            // Update message with failed status
            if let index = messages.firstIndex(where: { $0.id == tempID }) {
                messages[index] = optimisticMessage
                    .with(status: .failed(error: error.localizedDescription))
            }
        }
    }

    /// Retry sending a failed message
    /// - Parameter message: The message to retry
    public func retrySendMessage(_ message: Message) async {
        // Remove the failed message
        messages.removeAll { $0.id == message.id }

        // Send it again
        let parentMessage = message.replyTo.flatMap { replyToID in
            messages.first { $0.id == replyToID }
        }
        await sendMessage(text: message.content, replyTo: parentMessage)
    }

    // MARK: Private

    private let ndk: NDK
    private let threadEvent: NDKEvent
    private let projectReference: String
    private let userPubkey: String

    /// Subscribe to messages and update UI as they arrive
    /// This runs continuously in the background
    private func subscribeToMessages() async {
        do {
            // Create filter for messages in this thread (uses thread ID as the 'e' tag)
            let filter = Message.filter(for: threadID)

            let subscription = ndk.subscribeToEvents(filters: [filter])

            // Continuous subscription - runs forever
            for try await event in subscription {
                // Try to parse as Message
                if let message = Message.from(event: event) {
                    // Add to messages and keep sorted
                    messages.append(message)
                    messages.sort { $0.createdAt < $1.createdAt }
                }
            }
        } catch {
            // Set error message if subscription fails
            errorMessage = "Failed to subscribe to messages."
        }
    }
}
