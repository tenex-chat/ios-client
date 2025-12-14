//
// ChatInputViewModel.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation
import Observation
import TENEXCore

// MARK: - ChatInputViewModel

/// View model for chat input field
/// Tracks input text, selected agent, and mentioned pubkeys for p-tags
@MainActor
@Observable
public final class ChatInputViewModel {
    // MARK: Lifecycle

    /// Initialize the chat input view model
    /// - Parameter isNewThread: Whether this is a new thread (requires agent selection)
    public init(isNewThread: Bool = false) {
        self.isNewThread = isNewThread
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

    /// Whether the input bar is expanded
    public private(set) var isExpanded = false

    /// Pubkeys mentioned in the message (for p-tags)
    public private(set) var mentionedPubkeys: [String] = []

    /// Whether this is a new thread (determines if agent selection is required)
    public var isNewThread = false

    /// The current input text
    public var inputText = ""

    /// Whether an agent is required to send (computed from isNewThread)
    public var requiresAgent: Bool {
        self.isNewThread
    }

    /// Whether the send button should be enabled
    public var canSend: Bool {
        let hasText = !self.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasAgentIfRequired = !self.requiresAgent || self.selectedAgent != nil
        return hasText && hasAgentIfRequired
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

    /// Set the expanded state
    /// - Parameter expanded: Whether the input should be expanded
    public func setExpanded(_ expanded: Bool) {
        self.isExpanded = expanded
    }

    /// Clear the input text, mentions, nudges, and reply context
    public func clearInput() {
        self.inputText = ""
        self.mentionedPubkeys = []
        self.selectedNudges = []
        self.replyToMessage = nil
    }
}
