//
// Skill.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation
import NDKSwiftCore

// MARK: - Skill

/// Represents a skill (kind:4202) - reusable instruction sets for agents
/// Skills differ from nudges by potentially having NIP-94 file attachments
/// and being capability-focused rather than behavioral modifications
public struct Skill: Identifiable, Sendable {
    public let id: String
    public let pubkey: String
    public let title: String
    public let description: String?
    public let content: String
    public let hashtags: [String]
    public let createdAt: Date
    /// File attachment event IDs (e-tags referencing NIP-94 kind:1063 events)
    public let fileIDs: [String]

    // MARK: - Factory

    /// Create a Skill from an NDK event
    /// - Parameter event: The NDK event (must be kind:4202)
    /// - Returns: A Skill instance, or nil if the event is not a valid skill
    public static func from(event: NDKEvent) -> Self? {
        guard event.kind == 4202 else {
            return nil
        }

        // Extract file IDs from e-tags (NIP-94 references)
        let fileIDs = event.tags(withName: "e").compactMap { $0[safe: 1] }

        return Self(
            id: event.id,
            pubkey: event.pubkey,
            title: event.tagValue("title") ?? "Untitled Skill",
            description: event.tagValue("description"),
            content: event.content,
            hashtags: event.tags(withName: "t").compactMap { $0[safe: 1] },
            createdAt: Date(timeIntervalSince1970: TimeInterval(event.createdAt)),
            fileIDs: fileIDs
        )
    }

    /// Check if this skill has file attachments
    public var hasFiles: Bool {
        !fileIDs.isEmpty
    }
}
