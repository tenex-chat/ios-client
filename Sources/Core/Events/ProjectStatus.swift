//
// ProjectStatus.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation
import NDKSwiftCore

/// Represents a TENEX project status (Nostr kind:24_010)
/// Contains online agents with their models and tools
public struct ProjectStatus: Sendable {
    // MARK: Public

    /// The project identifier (from 'd' tag)
    public let projectID: String

    /// The pubkey of the status author
    public let pubkey: String

    /// Online agents parsed from agent/model/tool tags
    public let agents: [ProjectAgent]

    /// When the status was created
    public let createdAt: Date

    /// Create a ProjectStatus from a Nostr event
    /// - Parameter event: The NDKEvent (must be kind:24_010)
    /// - Returns: A ProjectStatus instance, or nil if the event is invalid
    public static func from(event: NDKEvent) -> Self? {
        // Verify correct kind
        guard event.kind == 24_010 else {
            return nil
        }

        // Extract 'd' tag (required)
        guard let dTag = event.tags(withName: "d").first,
              dTag.count > 1,
              !dTag[1].isEmpty
        else {
            return nil
        }
        let projectID = dTag[1]

        // Parse agents from tags
        let agents = parseAgents(from: event)

        // Convert timestamp to Date
        let createdAt = Date(timeIntervalSince1970: TimeInterval(event.createdAt))

        return Self(
            projectID: projectID,
            pubkey: event.pubkey,
            agents: agents,
            createdAt: createdAt
        )
    }

    /// Create a filter for fetching project status
    /// - Parameter projectId: The project identifier
    /// - Returns: An NDKFilter configured for kind:24_010 events
    public static func filter(for projectID: String) -> NDKFilter {
        NDKFilter(
            kinds: [24_010],
            tags: ["d": Set([projectID])]
        )
    }

    // MARK: Private

    /// Parse agents from event tags
    private static func parseAgents(from event: NDKEvent) -> [ProjectAgent] {
        var agentsByName = parseAgentTags(from: event)
        applyModelTags(from: event, to: &agentsByName)
        applyToolTags(from: event, to: &agentsByName)
        return Array(agentsByName.values)
    }

    /// Parse agent tags: ["agent", <pubkey>, <name>, "global"?]
    private static func parseAgentTags(from event: NDKEvent) -> [String: ProjectAgent] {
        var agentsByName: [String: ProjectAgent] = [:]
        for tag in event.tags(withName: "agent") {
            guard tag.count > 2, !tag[1].isEmpty, !tag[2].isEmpty else {
                continue
            }
            let agent = ProjectAgent(
                pubkey: tag[1],
                name: tag[2],
                isGlobal: tag.count > 3 && tag[3] == "global",
                model: nil,
                tools: []
            )
            agentsByName[tag[2]] = agent
        }
        return agentsByName
    }

    /// Apply model tags: ["model", <model-slug>, <agent-name>, ...]
    private static func applyModelTags(from event: NDKEvent, to agentsByName: inout [String: ProjectAgent]) {
        for tag in event.tags(withName: "model") {
            guard tag.count > 2, !tag[1].isEmpty else {
                continue
            }
            let modelSlug = tag[1]
            for agentName in tag.dropFirst(2) {
                if var agent = agentsByName[agentName] {
                    agent.model = modelSlug
                    agentsByName[agentName] = agent
                }
            }
        }
    }

    /// Apply tool tags: ["tool", <tool-name>, <agent-name>, ...]
    private static func applyToolTags(from event: NDKEvent, to agentsByName: inout [String: ProjectAgent]) {
        for tag in event.tags(withName: "tool") {
            guard tag.count > 2, !tag[1].isEmpty else {
                continue
            }
            let toolName = tag[1]
            for agentName in tag.dropFirst(2) {
                if var agent = agentsByName[agentName] {
                    agent.tools.append(toolName)
                    agentsByName[agentName] = agent
                }
            }
        }
    }
}
