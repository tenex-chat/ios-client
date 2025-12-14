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
    ///   - threadEvent: The thread event (kind:11) to reply to, or nil for new thread mode
    ///   - projectReference: The project reference in format "31933:pubkey:d-tag"
    ///   - userPubkey: The pubkey of the authenticated user
    ///   - aiConfigStorage: AI configuration storage for auto-TTS settings
    ///   - audioService: Audio service for TTS playback
    public init(
        ndk: NDK,
        threadEvent: NDKEvent?,
        projectReference: String,
        userPubkey: String,
        aiConfigStorage: AIConfigStorage? = nil,
        audioService: AudioService? = nil
    ) {
        self.ndk = ndk
        self.threadEvent = threadEvent
        self.projectReference = projectReference
        self.userPubkey = userPubkey
        self.aiConfigStorage = aiConfigStorage
        self.audioService = audioService

        // Initialize conversation state first (required before self can be captured)
        if let threadEvent {
            conversationState = ConversationState(rootEventID: threadEvent.id)
        } else {
            conversationState = ConversationState(rootEventID: "")
        }

        // Now set up the callback after all properties are initialized
        conversationState.onAgentMessage = { [weak self] message in
            self?.handleAgentMessage(message)
        }

        // Set up thread-specific initialization
        if let threadEvent {
            // Add the thread event (kind:11) as the first message
            // This is needed because the subscription only fetches kind:1111 replies
            if let threadMessage = Message.from(event: threadEvent) {
                conversationState.addMessage(threadMessage)
            }

            // Start continuous subscription in background
            Task {
                await subscribeToAllEvents()
            }
        }
    }

    // MARK: Public

    /// The conversation state managing messages, streaming, and typing
    public private(set) var conversationState: ConversationState

    /// The current error message, if any
    public private(set) var errorMessage: String?

    /// The most recent thread title from kind:513 metadata
    public private(set) var threadTitle: String?

    /// The thread event (kind:11) - nil for new thread mode, set after thread is created
    public private(set) var threadEvent: NDKEvent?

    /// Whether this is a new thread (no threadEvent yet)
    public var isNewThread: Bool {
        threadEvent == nil
    }

    /// The display messages (final + streaming synthetic), sorted by time
    /// Only includes root and direct replies to root (nested replies are hidden)
    public var displayMessages: [Message] {
        conversationState.displayMessages
    }

    /// All messages in the thread (for finding nested replies)
    public var allMessages: [String: Message] {
        conversationState.messages
    }

    /// Set of pubkeys of users who are currently typing
    public var typingUsers: Set<String> {
        Set(conversationState.typingIndicators.keys)
    }

    /// The thread ID derived from the thread event (nil if new thread)
    public var threadID: String? {
        threadEvent?.id
    }

    /// Subscribe to thread metadata (kind:513) to get the most recent title
    public func subscribeToThreadMetadata() async {
        guard let threadID else {
            return
        }

        // Create filter for metadata for this thread
        let filter = ConversationMetadata.filter(for: threadID)

        let subscription = ndk.subscribe(filter: filter)

        var latestMetadata: ConversationMetadata?

        for await event in subscription.events {
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
    }

    /// Send a new message to the thread, or create a new thread if threadEvent is nil
    /// - Parameters:
    ///   - text: The message text
    ///   - targetAgentPubkey: Agent pubkey to route message to (required for new threads)
    ///   - mentionedPubkeys: Pubkeys of mentioned users to add as p-tags
    ///   - replyTo: Optional parent message for replies
    ///   - selectedNudges: Selected nudge IDs
    ///   - selectedBranch: Selected git branch
    public func sendMessage(
        text: String,
        targetAgentPubkey: String? = nil,
        mentionedPubkeys: [String] = [],
        replyTo: Message? = nil,
        selectedNudges: [String] = [],
        selectedBranch: String? = nil
    ) async {
        // Validate message text
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            return
        }

        // For new threads, agent is required
        if isNewThread {
            guard let targetAgentPubkey else {
                errorMessage = "Please select an agent to start a thread"
                return
            }
            await createThread(
                content: trimmedText,
                agentPubkey: targetAgentPubkey,
                mentionedPubkeys: mentionedPubkeys,
                selectedNudges: selectedNudges,
                selectedBranch: selectedBranch
            )
            return
        }

        // Existing thread - send reply
        await sendReply(
            text: trimmedText,
            targetAgentPubkey: targetAgentPubkey,
            mentionedPubkeys: mentionedPubkeys,
            replyTo: replyTo,
            selectedNudges: selectedNudges,
            selectedBranch: selectedBranch
        )
    }

    // MARK: Private

    private let ndk: NDK
    private let projectReference: String
    private let userPubkey: String
    private let aiConfigStorage: AIConfigStorage?
    private let audioService: AudioService?

    /// Handle agent message for auto-TTS
    private func handleAgentMessage(_ message: Message) {
        // Check if message is from an agent (not the user)
        guard message.pubkey != userPubkey else {
            return
        }

        // Check if auto-TTS is enabled
        guard let aiConfigStorage,
              let aiConfig = try? aiConfigStorage.load(),
              aiConfig.ttsSettings.enabled,
              aiConfig.ttsSettings.autoSpeak else {
            return
        }

        // Trigger TTS for the agent's message
        guard let audioService else {
            return
        }

        // Trigger TTS in background
        Task {
            do {
                try await audioService.speak(text: message.content)
            } catch {
                // Silently fail for auto-TTS to not interrupt user experience
                // swiftlint:disable:next no_print_statements
                print("[ChatViewModel] Auto-TTS failed: \(error)")
            }
        }
    }

    /// Create a new thread (kind:11)
    private func createThread(
        content: String,
        agentPubkey: String,
        mentionedPubkeys: [String],
        selectedNudges: [String],
        selectedBranch: String?
    ) async {
        // Capture values for sendable closure
        let projectRef = projectReference
        let mentions = mentionedPubkeys
        let ndkInstance = ndk
        let nudges = selectedNudges
        let branch = selectedBranch

        do {
            // Build and publish thread event (kind:11)
            let (event, _) = try await ndk.publish { _ in
                buildThreadTags(
                    ndk: ndkInstance,
                    content: content,
                    projectRef: projectRef,
                    agentPubkey: agentPubkey,
                    mentions: mentions,
                    nudges: nudges,
                    branch: branch
                )
            }

            // Update threadEvent with the created thread
            threadEvent = event

            // Update conversation state with new root ID
            conversationState = ConversationState(
                rootEventID: event.id
            ) { [weak self] message in
                self?.handleAgentMessage(message)
            }

            // Add the thread as the first message (subscription only fetches kind:1111 replies)
            if let threadMessage = Message.from(event: event) {
                conversationState.addMessage(threadMessage)
            }

            // Start subscription for replies
            Task {
                await subscribeToAllEvents()
            }
        } catch {
            errorMessage = "Failed to create thread: \(error.localizedDescription)"
        }
    }

    /// Send a reply (kind:1111) to an existing thread
    private func sendReply( // swiftlint:disable:this function_parameter_count
        text: String,
        targetAgentPubkey: String?,
        mentionedPubkeys: [String],
        replyTo: Message?,
        selectedNudges: [String],
        selectedBranch: String?
    ) async {
        guard let threadEvent else {
            return
        }

        // Capture values for sendable closure
        let projectRef = projectReference
        let replyToMessage = replyTo
        let agentPubkey = targetAgentPubkey
        let mentions = mentionedPubkeys
        let nudges = selectedNudges
        let branch = selectedBranch

        // Publish reply - NDK handles signing, publishing, and retries
        // The subscription will pick up the event automatically
        let context = ReplyContext(
            projectRef: projectRef,
            replyTo: replyToMessage,
            agentPubkey: agentPubkey,
            mentions: mentions,
            selectedNudges: nudges,
            selectedBranch: branch
        )
        _ = try? await ndk.publish { _ in
            buildReplyTags(
                builder: NDKEventBuilder.reply(to: threadEvent, ndk: ndk),
                content: text,
                context: context
            )
        }
    }

    /// Subscribe to all event types and route through ConversationState
    private func subscribeToAllEvents() async {
        guard let threadID else {
            return
        }

        // Create two filters in one subscription:
        // Filter 1: kind 1111 (final messages) - no limits
        let finalMessagesFilter = NDKFilter(
            kinds: [1111],
            tags: ["E": Set([threadID])]
        )

        // Filter 2: ephemeral events (21111, 24111, 24112)
        // - since: 1 minute ago to prevent overwhelming with old events
        // - limit: 5 to cap the number of ephemeral events
        let oneMinuteAgo = Timestamp(Date().addingTimeInterval(-60).timeIntervalSince1970)
        let ephemeralFilter = NDKFilter(
            kinds: [21_111, 24_111, 24_112],
            since: oneMinuteAgo,
            limit: 5,
            tags: ["E": Set([threadID])]
        )

        // Use uppercase 'E' tag to get ALL events in the thread
        // (lowercase 'e' = direct parent, uppercase 'E' = root thread reference)
        let subscription = ndk.subscribe(filter: finalMessagesFilter.or(ephemeralFilter))

        // Continuous subscription - runs forever
        for await event in subscription.events {
            conversationState.processEvent(event)
        }
    }

    /// Build tags for a new thread (kind:11)
    private nonisolated func buildThreadTags( // swiftlint:disable:this function_parameter_count
        ndk: NDK,
        content: String,
        projectRef: String,
        agentPubkey: String,
        mentions: [String],
        nudges: [String],
        branch: String?
    ) -> NDKEventBuilder {
        var builder = NDKEventBuilder(ndk: ndk)
            .kind(11)
            .content(content, extractImeta: false)

        // Add project reference (a tag)
        builder = builder.tag(["a", projectRef])

        // Add title tag (first 50 chars of content)
        let title = String(content.prefix(50))
        builder = builder.tag(["title", title])

        // Extract hashtags from content and add as t tags
        let pattern = "#(\\w+)"
        if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
            let range = NSRange(content.startIndex..., in: content)
            let matches = regex.matches(in: content, options: [], range: range)
            for match in matches {
                if let tagRange = Range(match.range(at: 1), in: content) {
                    let hashtag = String(content[tagRange]).lowercased()
                    builder = builder.tag(["t", hashtag])
                }
            }
        }

        // Add agent p-tag (required for new threads)
        builder = builder.tag(["p", agentPubkey])

        // Add mentioned p-tags (excluding agent if already added)
        for pubkey in mentions where pubkey != agentPubkey {
            builder = builder.tag(["p", pubkey])
        }

        // Add nudge tags
        for nudgeID in nudges {
            builder = builder.tag(["nudge", nudgeID])
        }

        // Add branch tag
        if let branch {
            builder = builder.tag(["branch", branch])
        }

        return builder
    }

    /// Build tags for a reply message
    private nonisolated func buildReplyTags(
        builder: NDKEventBuilder,
        content: String,
        context: ReplyContext
    ) -> NDKEventBuilder {
        // Filter out auto p-tags only (keep e-tags from builder)
        let filteredTags = builder.tags.filter { $0.first != "p" }
        var newBuilder = builder.setTags(filteredTags)

        // Set content and project reference
        newBuilder = newBuilder.content(content, extractImeta: false)
        newBuilder = newBuilder.tag(["a", context.projectRef])

        // Add reply e-tag ONLY if replying to a specific message
        if let replyTo = context.replyTo {
            newBuilder = newBuilder.tag(["e", replyTo.id])
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

        // Add nudge tags
        for nudgeID in context.selectedNudges {
            newBuilder = newBuilder.tag(["nudge", nudgeID])
        }

        // Add branch tag
        if let branch = context.selectedBranch {
            newBuilder = newBuilder.tag(["branch", branch])
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
    let selectedNudges: [String]
    let selectedBranch: String?
}
