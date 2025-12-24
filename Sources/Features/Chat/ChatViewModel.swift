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
    ///   - settingsStorage: Storage for conversation settings
    public init(
        ndk: NDK,
        threadEvent: NDKEvent?,
        projectReference: String,
        userPubkey: String,
        aiConfigStorage: AIConfigStorage? = nil,
        audioService: AudioService? = nil,
        settingsStorage: ConversationSettingsStorage = UserDefaultsConversationSettingsStorage()
    ) {
        self.ndk = ndk
        self.threadEvent = threadEvent
        self.projectReference = projectReference
        self.userPubkey = userPubkey
        self.aiConfigStorage = aiConfigStorage
        self.audioService = audioService
        self.settingsStorage = settingsStorage

        // Load saved conversation settings
        self.conversationSettings = settingsStorage.load()

        // Initialize conversation state first (required before self can be captured)
        if let threadEvent {
            self.conversationState = ConversationState(rootEventID: threadEvent.id)

            // Set agent message callback after initialization to avoid capture issues
            self.conversationState.onAgentMessage = { [weak self] message in
                self?.handleAgentMessage(message)
            }

            // Add the thread event (kind:11) as the first message
            // This is needed because the subscription only fetches kind:1111 replies
            if let threadMessage = Message.from(event: threadEvent) {
                self.conversationState.addMessage(threadMessage)
            }

            // Start continuous subscription in background
            Task {
                await self.subscribeToAllEvents()
            }
        } else {
            // New thread mode - create empty conversation state (will be updated after thread creation)
            self.conversationState = ConversationState(rootEventID: "")

            // Set agent message callback after initialization to avoid capture issues
            self.conversationState.onAgentMessage = { [weak self] message in
                self?.handleAgentMessage(message)
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

    /// Conversation settings for debugging display options
    public var conversationSettings = ConversationSettings() {
        didSet {
            self.settingsStorage.save(self.conversationSettings)
        }
    }

    /// Whether this is a new thread (no threadEvent yet)
    public var isNewThread: Bool {
        self.threadEvent == nil
    }

    /// The display messages (final + streaming synthetic), sorted by time
    /// Only includes root and direct replies to root (nested replies are hidden)
    public var displayMessages: [Message] {
        self.conversationState.displayMessages
    }

    /// All messages in the thread (for finding nested replies)
    public var allMessages: [String: Message] {
        self.conversationState.messages
    }

    /// Set of pubkeys of users who are currently typing
    public var typingUsers: Set<String> {
        Set(self.conversationState.typingIndicators.keys)
    }

    /// The thread ID derived from the thread event (nil if new thread)
    public var threadID: String? {
        self.threadEvent?.id
    }

    /// Subscribe to thread metadata (kind:513) to get the most recent title
    public func subscribeToThreadMetadata() async {
        guard let threadID else {
            return
        }

        // Create filter for metadata for this thread
        let filter = ConversationMetadata.filter(for: threadID)

        let subscription = self.ndk.subscribe(filter: filter)

        var latestMetadata: ConversationMetadata?

        for await events in subscription.events {
            for event in events {
                // Try to parse as ConversationMetadata
                if let metadata = ConversationMetadata.from(event: event) {
                    // Only use metadata if it's newer than what we already have
                    if let existing = latestMetadata {
                        guard metadata.createdAt > existing.createdAt else {
                            continue
                        }
                    }
                    latestMetadata = metadata
                    self.threadTitle = metadata.title
                }
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
        selectedBranch: String? = nil,
        customTags: [[String]] = [],
        hashtag: String? = nil
    ) async {
        // Validate message text
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            return
        }

        // For new threads, either agent or hashtag is required
        if self.isNewThread {
            guard targetAgentPubkey != nil || hashtag != nil else {
                self.errorMessage = "Please select an agent or topic to start a thread"
                return
            }
            await self.createThread(
                content: trimmedText,
                agentPubkey: targetAgentPubkey,
                hashtag: hashtag,
                mentionedPubkeys: mentionedPubkeys,
                selectedNudges: selectedNudges,
                selectedBranch: selectedBranch
            )
            return
        }

        // Existing thread - send reply
        await self.sendReply(
            text: trimmedText,
            targetAgentPubkey: targetAgentPubkey,
            mentionedPubkeys: mentionedPubkeys,
            replyTo: replyTo,
            selectedNudges: selectedNudges,
            selectedBranch: selectedBranch,
            customTags: customTags
        )
    }

    // MARK: Private

    private let ndk: NDK
    private let projectReference: String
    private let userPubkey: String
    private let aiConfigStorage: AIConfigStorage?
    private let audioService: AudioService?
    private let settingsStorage: ConversationSettingsStorage

    /// Handle agent message for auto-TTS
    private func handleAgentMessage(_ message: Message) {
        // Check if message is from an agent (not the user)
        guard message.pubkey != self.userPubkey else {
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
    private func createThread( // swiftlint:disable:this function_parameter_count
        content: String,
        agentPubkey: String?,
        hashtag: String?,
        mentionedPubkeys: [String],
        selectedNudges: [String],
        selectedBranch: String?
    ) async {
        do {
            let publisher = MessagePublisher()
            let (event, _) = try await publisher.publishThread(
                ndk: self.ndk,
                content: content,
                projectRef: self.projectReference,
                agentPubkey: agentPubkey,
                hashtag: hashtag,
                mentions: mentionedPubkeys,
                nudges: selectedNudges,
                branch: selectedBranch
            )

            // Update threadEvent with the created thread
            self.threadEvent = event

            // Update conversation state with new root ID
            self.conversationState = ConversationState(rootEventID: event.id)

            // Set agent message callback after initialization to avoid capture issues
            self.conversationState.onAgentMessage = { [weak self] message in
                self?.handleAgentMessage(message)
            }

            // Add the thread as the first message (subscription only fetches kind:1111 replies)
            if let threadMessage = Message.from(event: event) {
                self.conversationState.addMessage(threadMessage)
            }

            // Start subscription for replies
            Task {
                await self.subscribeToAllEvents()
            }
        } catch {
            self.errorMessage = "Failed to create thread: \(error.localizedDescription)"
        }
    }

    /// Send a reply (kind:1111) to an existing thread
    private func sendReply( // swiftlint:disable:this function_parameter_count
        text: String,
        targetAgentPubkey: String?,
        mentionedPubkeys: [String],
        replyTo: Message?,
        selectedNudges: [String],
        selectedBranch: String?,
        customTags: [[String]] = []
    ) async {
        guard let threadEvent else {
            return
        }

        do {
            let publisher = MessagePublisher()
            _ = try await publisher.publishReply(
                ndk: self.ndk,
                threadEvent: threadEvent,
                content: text,
                projectRef: self.projectReference,
                agentPubkey: targetAgentPubkey,
                mentions: mentionedPubkeys,
                replyTo: replyTo?.id,
                nudges: selectedNudges,
                branch: selectedBranch,
                customTags: customTags
            )
        } catch {
            self.errorMessage = "Failed to send message: \(error.localizedDescription)"
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

        // Filter 2: ephemeral events (21111 streaming deltas)
        // - since: 1 minute ago to prevent overwhelming with old events
        // - limit: 5 to cap the number of ephemeral events
        let oneMinuteAgo = Timestamp(Date().addingTimeInterval(-60).timeIntervalSince1970)
        let ephemeralFilter = NDKFilter(
            kinds: [21_111],
            since: oneMinuteAgo,
            limit: 5,
            tags: ["E": Set([threadID])]
        )

        // Use uppercase 'E' tag to get ALL events in the thread
        // (lowercase 'e' = direct parent, uppercase 'E' = root thread reference)
        // Subscribe to both filters and process events from both
        let messagesSubscription = self.ndk.subscribe(filter: finalMessagesFilter)
        let ephemeralSubscription = self.ndk.subscribe(filter: ephemeralFilter)

        // Continuous subscriptions - run both in parallel
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                for await events in messagesSubscription.events {
                    for event in events {
                        await self.conversationState.processEvent(event)
                    }
                }
            }
            group.addTask {
                for await events in ephemeralSubscription.events {
                    for event in events {
                        await self.conversationState.processEvent(event)
                    }
                }
            }
        }
    }

    // Build tags for a new thread (kind:11)
}
