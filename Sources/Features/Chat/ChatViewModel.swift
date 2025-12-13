//
// ChatViewModel.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation
import NDKSwiftCoreCore
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
    ///   - threadId: The thread identifier
    ///   - userPubkey: The pubkey of the authenticated user
    public init(ndk: any NDKSubscribing & NDKPublishing, threadID: String, userPubkey: String) {
        self.ndk = ndk
        self.threadID = threadID
        self.userPubkey = userPubkey
    }

    // MARK: Public

    /// The list of messages
    public private(set) var messages: [Message] = []

    /// Whether messages are currently being loaded
    public private(set) var isLoading = false

    /// The current error message, if any
    public private(set) var errorMessage: String?

    /// Accumulated streaming content by message ID
    public private(set) var streamingContent: [String: String] = [:]

    /// Set of pubkeys of users who are currently typing
    public private(set) var typingUsers: Set<String> = []

    /// Load messages from Nostr
    public func loadMessages() async {
        // Clear error
        errorMessage = nil

        // Start loading
        isLoading = true

        defer {
            // Always stop loading when done
            isLoading = false
        }

        do {
            // Create filter for messages in this thread
            let filter = Message.filter(for: threadID)

            // Subscribe to messages
            var fetchedMessages: [Message] = []

            let subscription = ndk.subscribeToEvents(filters: [filter])

            for try await event in subscription {
                // Try to parse as Message
                if let message = Message.from(event: event) {
                    fetchedMessages.append(message)
                }
            }

            // Sort by creation date (oldest first for chat display)
            messages = fetchedMessages.sorted { $0.createdAt < $1.createdAt }
        } catch {
            // Set error message
            errorMessage = "Failed to load messages. Please try again."
        }
    }

    /// Subscribe to streaming deltas for real-time message updates
    public func subscribeToStreamingDeltas() async {
        do {
            // Subscribe to all streaming deltas for messages in this thread
            // We need to listen to all messages, so we create a broader filter
            let filter = NDKFilter(
                kinds: [21_111],
                tags: ["a": [threadID]]
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

    /// Refresh the messages list
    public func refresh() async {
        await loadMessages()
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
            threadID: threadID,
            content: trimmedText,
            createdAt: Date(),
            replyTo: replyTo?.id,
            status: .sending
        )

        // Add to messages immediately (optimistic update)
        messages.append(optimisticMessage)

        // Build event tags
        var tags: [[String]] = [
            ["a", threadID],
        ]

        // Add parent reference if replying
        if let replyTo {
            tags.append(["e", replyTo.id])
        }

        // Create the event
        let event = NDKEvent(
            pubkey: userPubkey,
            kind: 1111,
            tags: tags,
            content: trimmedText
        )

        do {
            // Publish the event
            try await ndk.publish(event)

            // Update message with sent status and event ID
            if let index = messages.firstIndex(where: { $0.id == tempID }) {
                messages[index] = optimisticMessage
                    .with(id: event.id ?? tempID)
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

    private let ndk: any NDKSubscribing & NDKPublishing
    private let threadID: String
    private let userPubkey: String
}
