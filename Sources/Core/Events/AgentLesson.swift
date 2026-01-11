//
// AgentLesson.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation
import NDKSwiftCore

// MARK: - AgentLesson

/// Represents an Agent Lesson event (Nostr kind 4129)
/// Documents agent learning with structured metadata
public struct AgentLesson: Identifiable, Sendable {
    // MARK: Lifecycle

    /// Initialize an AgentLesson from its properties
    public init(
        id: String,
        pubkey: String,
        createdAt: Date,
        agentDefinitionId: String?,
        title: String?,
        lesson: String,
        metacognition: String?,
        reasoning: String?,
        reflection: String?,
        detailed: String?,
        category: String?,
        hashtags: [String],
        event: NDKEvent
    ) {
        self.id = id
        self.pubkey = pubkey
        self.createdAt = createdAt
        self.agentDefinitionId = agentDefinitionId
        self.title = title
        self.lesson = lesson
        self.metacognition = metacognition
        self.reasoning = reasoning
        self.reflection = reflection
        self.detailed = detailed
        self.category = category
        self.hashtags = hashtags
        self.event = event
    }

    // MARK: Public

    /// Event kind for Agent Lessons
    public static let kind: UInt32 = 4129

    /// Event ID
    public let id: String

    /// Author pubkey (agent's pubkey)
    public let pubkey: String

    /// Creation timestamp
    public let createdAt: Date

    /// Reference to the agent definition event (e-tag)
    public let agentDefinitionId: String?

    /// Lesson title
    public let title: String?

    /// Main lesson content
    public let lesson: String

    /// Thinking about one's own thinking
    public let metacognition: String?

    /// Reasoning process
    public let reasoning: String?

    /// Reflections on learning
    public let reflection: String?

    /// Detailed explanation flag
    public let detailed: String?

    /// Lesson category/topic
    public let category: String?

    /// Hashtags for categorization
    public let hashtags: [String]

    /// Original NDKEvent for advanced operations
    public let event: NDKEvent

    /// Display title with fallback
    public var displayTitle: String {
        title ?? "Untitled Lesson"
    }

    /// Whether this lesson has detailed content
    public var hasDetailedContent: Bool {
        guard let detailed else {
            return false
        }
        return !detailed.isEmpty
    }

    /// Whether this lesson has learning metadata
    public var hasLearningMetadata: Bool {
        metacognition != nil || reasoning != nil || reflection != nil
    }

    /// Create an AgentLesson from an NDKEvent
    /// - Parameter event: The NDKEvent (must be kind 4129)
    /// - Returns: An AgentLesson instance, or nil if invalid
    public static func from(event: NDKEvent) -> Self? {
        guard event.kind == Self.kind else {
            return nil
        }

        let hashtags = event.tags(withName: "t")
            .compactMap { $0[safe: 1] }
            .map { String($0) }

        return Self(
            id: event.id,
            pubkey: event.pubkey,
            createdAt: Date(timeIntervalSince1970: TimeInterval(event.createdAt)),
            agentDefinitionId: event.tagValue("e"),
            title: event.tagValue("title"),
            lesson: event.content,
            metacognition: event.tagValue("metacognition"),
            reasoning: event.tagValue("reasoning"),
            reflection: event.tagValue("reflection"),
            detailed: event.tagValue("detailed"),
            category: event.tagValue("category"),
            hashtags: hashtags,
            event: event
        )
    }

    /// Create a filter for fetching lessons by agent pubkey
    /// - Parameter pubkey: The agent's pubkey
    /// - Returns: An NDKFilter configured for kind 4129 events
    public static func filter(forAgent pubkey: String) -> NDKFilter {
        NDKFilter(
            authors: [pubkey],
            kinds: [Int(Self.kind)],
            limit: 50
        )
    }

    /// Create a filter for fetching a specific lesson by ID
    /// - Parameter id: The lesson event ID
    /// - Returns: An NDKFilter configured for the specific event
    public static func filter(forLessonId id: String) -> NDKFilter {
        NDKFilter(
            ids: [id],
            kinds: [Int(Self.kind)]
        )
    }
}
