//
// ProjectStatus.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation
import NDKSwiftCore

/// Represents a TENEX project status (Nostr kind:24_010)
public struct ProjectStatus: Sendable {
    /// The project identifier (from 'd' tag)
    public let projectID: String

    /// The pubkey of the status author
    public let pubkey: String

    /// Array of online agent pubkeys
    public let onlineAgents: [String]

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

        // Extract online agents from tags (optional)
        let onlineAgents = event.tags(withName: "agent")
            .compactMap { tag -> String? in
                guard tag.count > 1, !tag[1].isEmpty else {
                    return nil
                }
                return tag[1]
            }

        // Convert timestamp to Date
        let createdAt = Date(timeIntervalSince1970: TimeInterval(event.createdAt))

        return Self(
            projectID: projectID,
            pubkey: event.pubkey,
            onlineAgents: onlineAgents,
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
}
