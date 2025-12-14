//
// ProjectAgent.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation

/// Represents an online agent in a TENEX project
/// Parsed from ProjectStatus (kind:24010) agent tags
public struct ProjectAgent: Identifiable, Sendable, Equatable {
    // MARK: Lifecycle

    /// Initialize a ProjectAgent
    /// - Parameters:
    ///   - pubkey: The agent's Nostr pubkey
    ///   - name: The agent's display name
    ///   - isGlobal: Whether the agent is global
    ///   - isPM: Whether this agent is the PM (first agent in 24010 event)
    ///   - model: Optional LLM model
    ///   - tools: Available tools
    public init(
        pubkey: String,
        name: String,
        isGlobal: Bool = false,
        isPM: Bool = false,
        model: String? = nil,
        tools: [String] = []
    ) {
        self.pubkey = pubkey
        self.name = name
        self.isGlobal = isGlobal
        self.isPM = isPM
        self.model = model
        self.tools = tools
    }

    // MARK: Public

    /// The agent's Nostr pubkey
    public let pubkey: String

    /// The agent's display name (denormalized from agent tag)
    public let name: String

    /// Whether this agent is global (available across all projects)
    public let isGlobal: Bool

    /// Whether this agent is the PM (Project Manager) - the first agent in the 24010 event
    public let isPM: Bool

    /// The LLM model this agent is using (from model tags)
    public var model: String?

    /// Tools available to this agent (from tool tags)
    public var tools: [String]

    /// Identifiable conformance
    public var id: String { pubkey }
}
