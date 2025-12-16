//
// ChatDraft.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation

// MARK: - ChatDraft

/// Represents a draft message that the user is composing
/// Drafts are persisted locally to prevent data loss
public struct ChatDraft: Codable, Equatable, Sendable {
    // MARK: Lifecycle

    /// Initialize a new chat draft
    /// - Parameters:
    ///   - conversationID: The conversation/thread ID (or project reference if new thread)
    ///   - text: The draft message text
    ///   - selectedAgent: The selected agent pubkey, if any
    ///   - selectedBranch: The selected git branch, if any
    ///   - selectedNudges: Selected nudge IDs
    ///   - mentionedPubkeys: Pubkeys mentioned in the message
    ///   - lastModified: Timestamp of last modification
    public init(
        conversationID: String,
        text: String,
        selectedAgent: String? = nil,
        selectedBranch: String? = nil,
        selectedNudges: [String] = [],
        mentionedPubkeys: [String] = [],
        lastModified: Date = Date()
    ) {
        self.conversationID = conversationID
        self.text = text
        self.selectedAgent = selectedAgent
        self.selectedBranch = selectedBranch
        self.selectedNudges = selectedNudges
        self.mentionedPubkeys = mentionedPubkeys
        self.lastModified = lastModified
    }

    // MARK: Public

    /// The conversation/thread ID (or project reference if new thread)
    public let conversationID: String

    /// The draft message text
    public let text: String

    /// The selected agent pubkey, if any
    public let selectedAgent: String?

    /// The selected git branch, if any
    public let selectedBranch: String?

    /// Selected nudge IDs
    public let selectedNudges: [String]

    /// Pubkeys mentioned in the message
    public let mentionedPubkeys: [String]

    /// Timestamp of last modification
    public let lastModified: Date

    /// Whether the draft is empty (no meaningful content)
    public var isEmpty: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
