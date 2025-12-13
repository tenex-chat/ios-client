//
// NDKAgentDefinition.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation
import NDKSwiftCore

/// Represents an Agent Definition (Nostr kind: 4199)
/// Defines the behavior, role, and capabilities of an AI agent
public struct NDKAgentDefinition: Identifiable, Sendable {
    // MARK: Lifecycle

    /// Initialize from an NDKEvent
    /// - Parameter event: The source event (must be kind 4199)
    public init?(from event: NDKEvent) {
        guard event.kind == 4199 else { return nil }
        self.event = event
        self.id = event.id
        self.pubkey = event.pubkey
        self.createdAt = Date(timeIntervalSince1970: TimeInterval(event.createdAt))
    }

    // MARK: Public

    public let id: String
    public let pubkey: String
    public let createdAt: Date
    public let event: NDKEvent

    /// The name of the agent (from 'title' tag)
    public var name: String {
        event.tags(withName: "title").first?.dropFirst().first ?? ""
    }

    /// The description of the agent (from 'description' tag or content)
    public var description: String {
        event.tags(withName: "description").first?.dropFirst().first ?? event.content
    }

    /// The role of the agent (from 'role' tag), defaults to 'assistant'
    public var role: String {
        event.tags(withName: "role").first?.dropFirst().first ?? "assistant"
    }

    /// The instructions/prompt for the agent (from content)
    public var instructions: String {
        event.content
    }

    /// Criteria for when to use this agent
    public var useCriteria: [String] {
        event.tags(withName: "use-criteria").compactMap { $0.count > 1 ? $0[1] : nil }
    }

    /// The model to use (from 'model' tag)
    public var model: String? {
        event.tags(withName: "model").first?.dropFirst().first
    }

    /// Profile picture URL (from 'picture' or 'image' tag)
    public var picture: String? {
        event.tags(withName: "picture").first?.dropFirst().first ??
        event.tags(withName: "image").first?.dropFirst().first
    }

    /// Version string
    public var version: String? {
        event.tags(withName: "version").first?.dropFirst().first
    }

    /// Slug (d-tag)
    public var slug: String? {
        event.tags(withName: "d").first?.dropFirst().first
    }

    /// List of direct tools
    public var tools: [String] {
        event.tags(withName: "tool").compactMap { $0.count > 1 ? $0[1] : nil }
    }

    /// List of MCP server event IDs
    public var mcpServers: [String] {
        event.tags(withName: "mcp").compactMap { $0.count > 1 ? $0[1] : nil }
    }

    /// List of phases
    public var phases: [AgentPhase] {
        event.tags(withName: "phase").compactMap { tag in
            guard tag.count > 2 else { return nil }
            return AgentPhase(name: tag[1], instructions: tag[2])
        }
    }
}

/// A phase in the agent's workflow
public struct AgentPhase: Sendable, Hashable {
    public let name: String
    public let instructions: String
}
