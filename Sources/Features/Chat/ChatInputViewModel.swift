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
    public init() {}

    // MARK: Public

    /// The currently selected agent pubkey
    public private(set) var selectedAgent: String?

    /// The currently selected branch ID
    public private(set) var selectedBranch: String?

    /// Selected nudge IDs
    public private(set) var selectedNudges: [String] = []

    /// Message we're replying to (for swipe-to-reply)
    public private(set) var replyToMessage: Message?

    /// Whether the input bar is expanded
    public private(set) var isExpanded = false

    /// Pubkeys mentioned in the message (for p-tags)
    public private(set) var mentionedPubkeys: [String] = []

    /// Whether the send button should be enabled
    public private(set) var canSend = false

    /// Whether an agent is required to send (e.g., for new threads)
    public private(set) var requiresAgent = false

    /// The current input text
    public var inputText = "" {
        didSet {
            updateCanSend()
        }
    }

    /// Set whether an agent is required to send
    /// - Parameter required: True if agent selection is required
    public func setRequiresAgent(_ required: Bool) {
        requiresAgent = required
        updateCanSend()
    }

    /// Select an agent
    /// - Parameter pubkey: The agent's pubkey
    public func selectAgent(_ pubkey: String) {
        selectedAgent = pubkey
        updateCanSend()
    }

    /// Select a branch
    /// - Parameter branchId: The branch identifier
    public func selectBranch(_ branchID: String) {
        selectedBranch = branchID
    }

    /// Insert a mention replacement into the text
    /// - Parameters:
    ///   - replacement: The text to insert (agent name)
    ///   - pubkey: The agent's pubkey to track for p-tag
    public func insertMention(replacement: String, pubkey: String) {
        // Track the mentioned pubkey for p-tag generation
        if !mentionedPubkeys.contains(pubkey) {
            mentionedPubkeys.append(pubkey)
        }

        // Replace the last @... with the agent name
        if let atRange = inputText.range(of: "@", options: .backwards) {
            inputText = String(inputText[..<atRange.lowerBound]) + replacement + " "
        }
    }

    /// Toggle a nudge selection
    /// - Parameter nudgeId: The nudge ID to toggle
    public func toggleNudge(_ nudgeID: String) {
        if selectedNudges.contains(nudgeID) {
            selectedNudges.removeAll { $0 == nudgeID }
        } else {
            selectedNudges.append(nudgeID)
        }
    }

    /// Set the message to reply to
    /// - Parameter message: The message to reply to, or nil to clear
    public func setReplyTo(_ message: Message?) {
        replyToMessage = message
    }

    /// Clear the reply context
    public func clearReplyTo() {
        replyToMessage = nil
    }

    /// Set the expanded state
    /// - Parameter expanded: Whether the input should be expanded
    public func setExpanded(_ expanded: Bool) {
        isExpanded = expanded
    }

    /// Clear the input text, mentions, nudges, and reply context
    public func clearInput() {
        inputText = ""
        mentionedPubkeys = []
        selectedNudges = []
        replyToMessage = nil
    }

    // MARK: Private

    private func updateCanSend() {
        let hasText = !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasAgentIfRequired = !requiresAgent || selectedAgent != nil
        canSend = hasText && hasAgentIfRequired
    }
}
