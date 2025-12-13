//
// Project.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation
import NDKSwiftCore
import SwiftUI
import TENEXShared

/// Represents a TENEX project (Nostr kind:31_933)
public struct Project: Identifiable, Sendable {
    // MARK: Public

    /// The project identifier (from 'd' tag)
    public let id: String

    /// The pubkey of the project author
    public let pubkey: String

    /// The project title
    public let title: String

    /// Optional project description
    public let description: String?

    /// Optional project picture URL
    public let picture: String?

    /// Optional repository URL
    public let repoUrl: String?

    /// List of hashtags
    public let hashtags: [String]

    /// List of agent IDs (kind 4199 event IDs)
    public let agentIds: [String]

    /// List of MCP tool IDs (kind 4200 event IDs)
    public let mcpToolIds: [String]

    /// When the project was created
    public let createdAt: Date

    /// Deterministic color based on project ID
    public let color: Color

    /// The addressable event coordinate for this project (kind:pubkey:dTag)
    /// Used for referencing this project in #a tags
    public var coordinate: String {
        "31933:\(pubkey):\(id)"
    }

    /// Create a Project from a Nostr event
    /// - Parameter event: The NDKEvent (must be kind:31_933)
    /// - Returns: A Project instance, or nil if the event is invalid
    public static func from(event: NDKEvent) -> Self? {
        // Verify correct kind
        guard event.kind == 31_933 else {
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

        // Extract title from tags (required)
        guard let titleTag = event.tags(withName: "title").first,
              titleTag.count > 1
        else {
            return nil
        }
        let title = titleTag[1]

        // Extract description from JSON content (optional)
        // Fallback to content if not JSON
        let description = parseDescription(from: event.content) ?? event.content

        // Extract other metadata
        let picture = event.tags(withName: "picture").first?.count ?? 0 > 1 ? event.tags(withName: "picture").first?[1] : nil
            ?? event.tags(withName: "image").first?.count ?? 0 > 1 ? event.tags(withName: "image").first?[1] : nil

        let repoUrl = event.tags(withName: "repo").first?.count ?? 0 > 1 ? event.tags(withName: "repo").first?[1] : nil

        let hashtags = event.tags.filter { $0.count > 1 && $0[0] == "t" }.map { $0[1] }

        let agentIds = event.tags.filter { $0.count > 1 && $0[0] == "agent" }.map { $0[1] }

        let mcpToolIds = event.tags.filter { $0.count > 1 && $0[0] == "mcp" }.map { $0[1] }

        // Convert timestamp to Date
        let createdAt = Date(timeIntervalSince1970: TimeInterval(event.createdAt))

        // Generate deterministic color from project ID
        let color = Color.deterministicColor(for: projectID)

        return Self(
            id: projectID,
            pubkey: event.pubkey,
            title: title,
            description: description,
            picture: picture,
            repoUrl: repoUrl,
            hashtags: hashtags,
            agentIds: agentIds,
            mcpToolIds: mcpToolIds,
            createdAt: createdAt,
            color: color
        )
    }

    /// Create a filter for fetching projects by author
    /// - Parameter pubkey: The author's pubkey
    /// - Returns: An NDKFilter configured for kind:31_933 events
    public static func filter(for pubkey: String) -> NDKFilter {
        NDKFilter(
            authors: [pubkey],
            kinds: [31_933]
        )
    }

    // MARK: Private

    // MARK: - Private Helpers

    private static func parseDescription(from content: String) -> String? {
        guard let data = content.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let description = json["description"] as? String,
              !description.isEmpty
        else {
            return nil
        }
        return description
    }
}
