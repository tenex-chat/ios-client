//
// ChatInputViewModel.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation
import Observation

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

    /// Clear the input text and mentions
    public func clearInput() {
        inputText = ""
        mentionedPubkeys = []
    }

    // MARK: Private

    private func updateCanSend() {
        let hasText = !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasAgentIfRequired = !requiresAgent || selectedAgent != nil
        canSend = hasText && hasAgentIfRequired
    }
}
