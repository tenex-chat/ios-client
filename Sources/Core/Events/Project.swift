//
// Project.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation
import NDKSwift
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

    /// When the project was created
    public let createdAt: Date

    /// Deterministic color based on project ID
    public let color: Color

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
        let description = parseDescription(from: event.content)

        // Convert timestamp to Date
        let createdAt = Date(timeIntervalSince1970: TimeInterval(event.createdAt))

        // Generate deterministic color from project ID
        let color = Color.deterministicColor(for: projectID)

        return Self(
            id: projectID,
            pubkey: event.pubkey,
            title: title,
            description: description,
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
