//
// ProcessedMessage.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation

/// Lightweight processed message for storage efficiency
public struct ProcessedMessage: Sendable, Identifiable {
    public let id: String
    public let threadID: String
    public let pubkey: String
    public let content: String
    public let createdAt: Date
    public let replyToMessageID: String?

    /// Initialize from raw event data (called from background)
    public init(
        id: String,
        threadID: String,
        pubkey: String,
        content: String,
        createdAt: Date,
        replyToMessageID: String?
    ) {
        self.id = id
        self.threadID = threadID
        self.pubkey = pubkey
        self.content = content
        self.createdAt = createdAt
        self.replyToMessageID = replyToMessageID
    }
}
