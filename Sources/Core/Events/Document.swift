//
// Document.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation
import NDKSwiftCore

// MARK: - Document

/// Represents a TENEX document (Nostr kind 30023 - Long-form content)
/// NIP-23 compliant long-form article with version tracking support
public struct Document: Identifiable, Sendable {
    // MARK: Lifecycle

    /// Initialize a Document from its properties
    public init(
        id: String,
        dTag: String,
        pubkey: String,
        title: String,
        summary: String?,
        content: String,
        hashtags: [String],
        publishedAt: Date?,
        createdAt: Date,
        projectCoordinate: String?,
        event: NDKEvent
    ) {
        self.id = id
        self.dTag = dTag
        self.pubkey = pubkey
        self.title = title
        self.summary = summary
        self.content = content
        self.hashtags = hashtags
        self.publishedAt = publishedAt
        self.createdAt = createdAt
        self.projectCoordinate = projectCoordinate
        self.event = event
    }

    // MARK: Public

    /// Event ID
    public let id: String

    /// Document identifier (d-tag) for addressable events
    public let dTag: String

    /// Author pubkey
    public let pubkey: String

    /// Document title
    public let title: String

    /// Summary/excerpt
    public let summary: String?

    /// Full markdown content
    public let content: String

    /// Hashtags from "t" tags
    public let hashtags: [String]

    /// Publication date (from "published_at" tag)
    public let publishedAt: Date?

    /// Event creation timestamp
    public let createdAt: Date

    /// Project reference (from "a" tag)
    public let projectCoordinate: String?

    /// Original NDKEvent for advanced operations
    public let event: NDKEvent

    /// Estimated reading time in minutes (200 words per minute)
    public var readingTimeMinutes: Int {
        let words = content
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: " ")
            .count
        return max(1, Int(ceil(Double(words) / 200.0)))
    }

    /// Create a Document from an NDKEvent
    /// - Parameter event: The NDKEvent (must be kind 30023)
    /// - Returns: A Document instance, or nil if invalid
    public static func from(event: NDKEvent) -> Self? {
        guard event.kind == 30_023 else {
            return nil
        }

        let dTag = event.tagValue("d") ?? ""
        let title = event.tagValue("title") ?? event.tagValue("name") ?? "Untitled"
        let summary = event.tagValue("summary")
        let hashtags = event.tags(withName: "t").compactMap { $0[safe: 1] }.map { String($0) }
        let projectCoordinate = event.tagValue("a")

        let publishedAt: Date?
        if let timestamp = event.tagValue("published_at"),
           let seconds = Int(timestamp) {
            publishedAt = Date(timeIntervalSince1970: TimeInterval(seconds))
        } else {
            publishedAt = nil
        }

        let createdAt = Date(timeIntervalSince1970: TimeInterval(event.createdAt))

        return Self(
            id: event.id,
            dTag: dTag,
            pubkey: event.pubkey,
            title: title,
            summary: summary,
            content: event.content,
            hashtags: hashtags,
            publishedAt: publishedAt,
            createdAt: createdAt,
            projectCoordinate: projectCoordinate,
            event: event
        )
    }

    /// Create a filter for fetching documents by project
    /// - Parameter projectCoordinate: The project coordinate (e.g., "31933:pubkey:dtag")
    /// - Returns: An NDKFilter configured for kind 30023 events with project tag
    public static func filter(for projectCoordinate: String) -> NDKFilter {
        NDKFilter(
            kinds: [30_023],
            tags: ["a": [projectCoordinate]]
        )
    }

    /// Create a filter for fetching all versions of a document by d-tag and author
    /// - Parameters:
    ///   - dTag: The document d-tag
    ///   - pubkey: The author pubkey
    /// - Returns: An NDKFilter configured for fetching all versions
    public static func versionFilter(dTag: String, pubkey: String) -> NDKFilter {
        NDKFilter(
            authors: [pubkey],
            kinds: [30_023],
            tags: ["d": [dTag]]
        )
    }
}
