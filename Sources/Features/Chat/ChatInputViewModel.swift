//
// ChatInputViewModel.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation
import Observation
import OSLog
import TENEXCore

// MARK: - ChatInputViewModel

/// View model for chat input field
/// Tracks input text, selected agent, and mentioned pubkeys for p-tags
@MainActor
@Observable
public final class ChatInputViewModel {
    // MARK: Lifecycle

    /// Initialize the chat input view model
    /// - Parameters:
    ///   - conversationID: The conversation/thread ID (or project reference if new thread)
    ///   - isNewThread: Whether this is a new thread (requires agent selection)
    ///   - draftStorage: Storage for persisting drafts (optional, defaults to UserDefaults)
    public init(
        conversationID: String,
        isNewThread: Bool = false,
        draftStorage: ChatDraftStorage = UserDefaultsChatDraftStorage()
    ) {
        self.conversationID = conversationID
        self.isNewThread = isNewThread
        self.draftStorage = draftStorage

        // Restore draft if one exists
        self.restoreDraft()
    }

    // MARK: Public

    /// The currently selected agent pubkey
    public private(set) var selectedAgent: String?

    /// The currently selected branch ID
    public var selectedBranch: String?

    /// Selected nudge IDs
    public var selectedNudges: [String] = []

    /// Message we're replying to (for swipe-to-reply)
    public private(set) var replyToMessage: Message?

    /// Pubkeys mentioned in the message (for p-tags)
    public private(set) var mentionedPubkeys: [String] = []

    /// Whether this is a new thread (determines if agent selection is required)
    public var isNewThread = false

    /// The current input text
    public var inputText = "" {
        didSet {
            // Auto-save draft when text changes (debounced)
            debouncedSaveDraft()
        }
    }

    /// The selected hashtag for topic-based routing (mutually exclusive with agent)
    public var selectedHashtag: String?

    /// Error that occurred during draft save/restore operations
    public private(set) var draftSaveError: Error?

    /// The conversation/thread ID for this input
    private let conversationID: String

    /// Storage for persisting drafts
    private let draftStorage: ChatDraftStorage

    /// Task for debounced save operation
    private var debounceSaveTask: Task<Void, Never>?

    /// Whether routing is required (agent or hashtag) for new threads
    public var requiresRouting: Bool {
        self.isNewThread
    }

    /// Whether the send button should be enabled
    /// For new threads: requires either an agent or a hashtag
    /// For replies: can send without routing
    public var canSend: Bool {
        let hasText = !self.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasRoutingIfRequired = !self.requiresRouting || self.selectedAgent != nil || self.selectedHashtag != nil
        return hasText && hasRoutingIfRequired
    }

    /// Select an agent
    /// - Parameter pubkey: The agent's pubkey
    public func selectAgent(_ pubkey: String) {
        self.selectedAgent = pubkey
    }

    /// Select a branch
    /// - Parameter branchId: The branch identifier
    public func selectBranch(_ branchID: String) {
        self.selectedBranch = branchID
    }

    /// Insert a mention replacement into the text
    /// - Parameters:
    ///   - replacement: The text to insert (agent name)
    ///   - pubkey: The agent's pubkey to track for p-tag
    public func insertMention(replacement: String, pubkey: String) {
        // Track the mentioned pubkey for p-tag generation
        if !self.mentionedPubkeys.contains(pubkey) {
            self.mentionedPubkeys.append(pubkey)
        }

        // Replace the last @... with the agent name
        if let atRange = inputText.range(of: "@", options: .backwards) {
            self.inputText = String(self.inputText[..<atRange.lowerBound]) + replacement + " "
        }
    }

    /// Toggle a nudge selection
    /// - Parameter nudgeId: The nudge ID to toggle
    public func toggleNudge(_ nudgeID: String) {
        if self.selectedNudges.contains(nudgeID) {
            self.selectedNudges.removeAll { $0 == nudgeID }
        } else {
            self.selectedNudges.append(nudgeID)
        }
    }

    /// Set the message to reply to
    /// - Parameter message: The message to reply to, or nil to clear
    public func setReplyTo(_ message: Message?) {
        self.replyToMessage = message
    }

    /// Clear the reply context
    public func clearReplyTo() {
        self.replyToMessage = nil
    }

    /// Clear the input text, mentions, nudges, hashtag, and reply context
    public func clearInput() {
        self.inputText = ""
        self.mentionedPubkeys = []
        self.selectedNudges = []
        self.selectedHashtag = nil
        self.replyToMessage = nil

        // Delete draft when input is cleared (e.g., after sending)
        deleteDraft()
    }

    // MARK: - Draft Management

    private static let logger = Logger(subsystem: "com.tenex.client", category: "ChatInputViewModel")
    private static let debounceDuration: UInt64 = 500_000_000 // 500ms in nanoseconds

    /// Debounced save that waits for user to pause typing
    private func debouncedSaveDraft() {
        // Cancel any existing debounce task
        debounceSaveTask?.cancel()

        // Don't save empty drafts - delete immediately
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            deleteDraft()
            return
        }

        // Create new debounce task
        debounceSaveTask = Task {
            do {
                // Wait for debounce duration
                try await Task.sleep(nanoseconds: Self.debounceDuration)

                // If task was cancelled during sleep, don't save
                guard !Task.isCancelled else {
                    return
                }

                // Perform the actual save
                await performSave()
            } catch {
                // Task was cancelled or sleep failed - this is normal
            }
        }
    }

    /// Perform the actual save operation
    private func performSave() async {
        let draft = ChatDraft(
            conversationID: conversationID,
            text: inputText,
            selectedAgent: selectedAgent,
            selectedBranch: selectedBranch,
            selectedNudges: selectedNudges,
            mentionedPubkeys: mentionedPubkeys,
            lastModified: Date()
        )

        do {
            try await draftStorage.saveDraft(draft)
            // Clear error on successful save
            self.draftSaveError = nil
        } catch {
            // Store error for UI to display
            self.draftSaveError = error
            Self.logger.error("Failed to save draft: \(error.localizedDescription)")
        }
    }

    /// Restore draft from storage if one exists
    private func restoreDraft() {
        Task {
            do {
                if let draft = try await draftStorage.loadDraft(for: conversationID) {
                    // Restore all draft state
                    self.inputText = draft.text
                    self.selectedAgent = draft.selectedAgent
                    self.selectedBranch = draft.selectedBranch
                    self.selectedNudges = draft.selectedNudges
                    self.mentionedPubkeys = draft.mentionedPubkeys
                    // Clear any previous errors
                    self.draftSaveError = nil
                }
            } catch {
                // Store error for UI to display
                self.draftSaveError = error
                Self.logger.error("Failed to restore draft: \(error.localizedDescription)")
            }
        }
    }

    /// Delete the draft for this conversation
    private func deleteDraft() {
        // Cancel any pending save
        debounceSaveTask?.cancel()

        Task {
            do {
                try await draftStorage.deleteDraft(for: conversationID)
                // Clear error on successful delete
                self.draftSaveError = nil
            } catch {
                // Store error for UI to display
                self.draftSaveError = error
                Self.logger.error("Failed to delete draft: \(error.localizedDescription)")
            }
        }
    }
}
