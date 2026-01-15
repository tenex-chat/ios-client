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

    /// Initialize the chat view model with an existing thread event
    /// - Parameters:
    ///   - ndk: The NDK instance for fetching and publishing messages
    ///   - threadEvent: The thread event (kind:1) to reply to, or nil for new thread mode
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
        self._threadIDOverride = nil

        // Load saved conversation settings
        self.conversationSettings = settingsStorage.load()

        // Initialize conversation state first (required before self can be captured)
        if let threadEvent {
            self.conversationState = ConversationState(rootEventID: threadEvent.id)

            // Set agent message callback after initialization to avoid capture issues
            self.conversationState.onAgentMessage = { [weak self] message in
                self?.handleAgentMessage(message)
            }

            // Add the thread event as the first message
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

    /// Initialize the chat view model with just a thread ID (for existing threads)
    /// This initializer is for event-based navigation where we don't need to fetch the thread event first.
    /// Messages will be loaded via subscription.
    /// - Parameters:
    ///   - ndk: The NDK instance for fetching and publishing messages
    ///   - threadID: The thread ID (event ID of the kind:1 thread event)
    ///   - projectReference: The project reference in format "31933:pubkey:d-tag"
    ///   - userPubkey: The pubkey of the authenticated user
    ///   - aiConfigStorage: AI configuration storage for auto-TTS settings
    ///   - audioService: Audio service for TTS playback
    ///   - settingsStorage: Storage for conversation settings
    public init(
        ndk: NDK,
        threadID: String,
        projectReference: String,
        userPubkey: String,
        aiConfigStorage: AIConfigStorage? = nil,
        audioService: AudioService? = nil,
        settingsStorage: ConversationSettingsStorage = UserDefaultsConversationSettingsStorage()
    ) {
        self.ndk = ndk
        self.threadEvent = nil // Will be populated when subscription receives it
        self.projectReference = projectReference
        self.userPubkey = userPubkey
        self.aiConfigStorage = aiConfigStorage
        self.audioService = audioService
        self.settingsStorage = settingsStorage
        self._threadIDOverride = threadID

        // Load saved conversation settings
        self.conversationSettings = settingsStorage.load()

        // Initialize conversation state with the thread ID
        self.conversationState = ConversationState(rootEventID: threadID)

        // Set agent message callback after initialization to avoid capture issues
        self.conversationState.onAgentMessage = { [weak self] message in
            self?.handleAgentMessage(message)
        }

        // Start continuous subscription in background - this will fetch all messages
        Task {
            await self.subscribeToAllEvents()
        }
    }

    // MARK: Public

    /// The conversation state managing messages, streaming, and typing
    public private(set) var conversationState: ConversationState

    /// The current error message, if any
    public private(set) var errorMessage: String?

    /// The most recent thread title from kind:513 metadata
    public private(set) var threadTitle: String?

    /// The thread event (kind:1) - nil for new thread mode, set after thread is created
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

    /// All messages in the thread
    public var allMessages: [String: Message] {
        self.conversationState.messages
    }

    /// The thread ID derived from the thread event or override (nil if new thread)
    public var threadID: String? {
        self._threadIDOverride ?? self.threadEvent?.id
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
        hashtag: String? = nil,
        attachmentURLs: [String] = []
    ) async {
        // Build content with attachment URLs appended
        var contentParts = [text.trimmingCharacters(in: .whitespacesAndNewlines)]
        contentParts.append(contentsOf: attachmentURLs)
        let finalContent = contentParts.joined(separator: "\n")

        // Validate message content (must have text or attachments)
        guard !finalContent.isEmpty else {
            return
        }

        // For new threads, either agent or hashtag is required
        if self.isNewThread {
            guard targetAgentPubkey != nil || hashtag != nil else {
                self.errorMessage = "Please select an agent or topic to start a thread"
                return
            }
            await self.createThread(
                content: finalContent,
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
            text: finalContent,
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
    private let _threadIDOverride: String?

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

    /// Create a new thread (kind:1)
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

            // Add the thread as the first message
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

    /// Send a reply (kind:1) to an existing thread
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

    /// Subscribe to all messages (kind:1) in the thread
    private func subscribeToAllEvents() async {
        guard let threadID else {
            return
        }

        // Subscribe to root event and replies in parallel
        let rootSubscription = ndk.subscribe(filter: NDKFilter(ids: [threadID]))
        let repliesSubscription = ndk.subscribe(filter: NDKFilter(kinds: [1], tags: ["e": Set([threadID])]))

        await withTaskGroup(of: Void.self) { group in
            group.addTask { @MainActor in
                for await events in rootSubscription.events {
                    for event in events {
                        self.threadEvent = event
                        self.conversationState.processEvent(event)
                    }
                }
            }

            group.addTask { @MainActor in
                for await events in repliesSubscription.events {
                    for event in events {
                        self.conversationState.processEvent(event)
                    }
                }
            }
        }
    }
}
