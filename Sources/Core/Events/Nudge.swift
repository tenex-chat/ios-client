//
// Nudge.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation
import NDKSwiftCore

// MARK: - Nudge

/// Represents a system prompt modifier (kind:4201)
/// Nudges are reusable prompt snippets that modify AI behavior
public struct Nudge: Identifiable, Sendable {
    public let id: String
    public let pubkey: String
    public let title: String
    public let description: String?
    public let content: String
    public let hashtags: [String]
    public let createdAt: Date

    // MARK: - Factory

    /// Create a Nudge from an NDK event
    /// - Parameter event: The NDK event (must be kind:4201)
    /// - Returns: A Nudge instance, or nil if the event is not a valid nudge
    public static func from(event: NDKEvent) -> Self? {
        guard event.kind == 4201 else {
            return nil
        }

        return Self(
            id: event.id,
            pubkey: event.pubkey,
            title: event.tagValue("title") ?? "Untitled",
            description: event.tagValue("description"),
            content: event.content,
            hashtags: event.tags(withName: "t").compactMap { $0[safe: 1] },
            createdAt: Date(timeIntervalSince1970: TimeInterval(event.createdAt))
        )
    }
}
