//
// AgentDefinition.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation
import NDKSwiftCore

/// Represents an Agent Definition (Nostr kind:4199)
public struct AgentDefinition: Identifiable, Sendable, Equatable {
    /// The event ID
    public let id: String

    /// The pubkey of the agent author
    public let pubkey: String

    /// The agent name
    public let name: String

    /// The agent description
    public let description: String?

    /// The agent role (default: "assistant")
    public let role: String

    /// The agent instructions/system prompt
    public let instructions: String?

    /// The agent model (e.g., "gpt-4")
    public let model: String?

    /// The agent picture URL
    public let picture: String?

    /// The agent version
    public let version: String?

    /// The unique identifier (d tag)
    public let slug: String?

    /// List of tool names this agent uses
    public let tools: [String]

    /// List of MCP server event IDs this agent uses
    public let mcpServers: [String]

    /// Criteria for when this agent should be used
    public let useCriteria: [String]

    /// Phases defining multi-step agent behavior
    public let phases: [(name: String, instructions: String)]

    /// When the agent was created
    public let createdAt: Date

    /// Equatable conformance (required due to named tuple in phases)
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id &&
            lhs.pubkey == rhs.pubkey &&
            lhs.name == rhs.name &&
            lhs.description == rhs.description &&
            lhs.role == rhs.role &&
            lhs.instructions == rhs.instructions &&
            lhs.model == rhs.model &&
            lhs.picture == rhs.picture &&
            lhs.version == rhs.version &&
            lhs.slug == rhs.slug &&
            lhs.tools == rhs.tools &&
            lhs.mcpServers == rhs.mcpServers &&
            lhs.useCriteria == rhs.useCriteria &&
            lhs.phases.count == rhs.phases.count &&
            zip(lhs.phases, rhs.phases).allSatisfy { $0.name == $1.name && $0.instructions == $1.instructions } &&
            lhs.createdAt == rhs.createdAt
    }

    /// Create an AgentDefinition from a Nostr event
    /// - Parameter event: The NDKEvent (must be kind:4199)
    /// - Returns: An AgentDefinition instance, or nil if the event is invalid
    public static func from(event: NDKEvent) -> Self? {
        guard event.kind == 4199 else {
            return nil
        }

        let name = event.tags(withName: "title").first?.count ?? 0 > 1 ?
            event.tags(withName: "title").first?[1] : nil
            ?? event.tags(withName: "name").first?.count ?? 0 > 1 ?
            event.tags(withName: "name").first?[1] : nil
            ?? ""

        let description = event.tags(withName: "description").first?.count ?? 0 > 1 ?
            event.tags(withName: "description").first?[1] : event.content

        let role = event.tags(withName: "role").first?.count ?? 0 > 1 ?
            event.tags(withName: "role").first?[1] ?? "assistant" : "assistant"

        let instructions = event.content

        let model = event.tags(withName: "model").first?.count ?? 0 > 1 ?
            event.tags(withName: "model").first?[1] : nil

        let picture = event.tags(withName: "picture").first?.count ?? 0 > 1 ?
            event.tags(withName: "picture").first?[1] : nil
            ?? event.tags(withName: "image").first?.count ?? 0 > 1 ?
            event.tags(withName: "image").first?[1] : nil

        let version = event.tags(withName: "version").first?.count ?? 0 > 1 ?
            event.tags(withName: "version").first?[1] : nil

        let slug = event.tags(withName: "d").first?.count ?? 0 > 1 ?
            event.tags(withName: "d").first?[1] : nil

        let tools = event.tags.filter { $0.count > 1 && $0[0] == "tool" }.map { $0[1] }

        let mcpServers = event.tags.filter { $0.count > 1 && $0[0] == "mcp" }.map { $0[1] }

        let useCriteria = event.tags.filter { $0.count > 1 && $0[0] == "use-criteria" }.map { $0[1] }

        let phases = event.tags.filter { $0.count > 2 && $0[0] == "phase" }.map { (name: $0[1], instructions: $0[2]) }

        return Self(
            id: event.id,
            pubkey: event.pubkey,
            name: name ?? "",
            description: description,
            role: role,
            instructions: instructions,
            model: model,
            picture: picture,
            version: version,
            slug: slug,
            tools: tools,
            mcpServers: mcpServers,
            useCriteria: useCriteria,
            phases: phases,
            createdAt: Date(timeIntervalSince1970: TimeInterval(event.createdAt))
        )
    }
}
