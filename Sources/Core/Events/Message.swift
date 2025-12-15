//
// Message.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation
import NDKSwiftCore
import TENEXShared

// MARK: - ToolCall

/// Represents a tool call extracted from a Nostr event
public struct ToolCall: Sendable {
    // MARK: Public

    /// The name of the tool being called
    public let name: String

    /// The parsed arguments for the tool
    public let args: [String: AnySendable]

    /// Project d-tag extracted from the event's "a" tag
    public let projectDTag: String?

    /// Branch name extracted from the event's "branch" tag
    public let branch: String?

    /// Whether this is a tool call event
    public var isToolCall: Bool { true }

    /// Convert a full file path to a display-friendly relative path
    public static func getDisplayPath(fullPath: String, projectDTag: String?, branch: String?) -> String {
        if fullPath.isEmpty {
            return ""
        }

        guard let projectDTag, !projectDTag.isEmpty else {
            return URL(fileURLWithPath: fullPath).lastPathComponent
        }

        guard let dTagRange = fullPath.range(of: projectDTag) else {
            return URL(fileURLWithPath: fullPath).lastPathComponent
        }

        var relativePath = String(fullPath[dTagRange.upperBound...])

        if relativePath.hasPrefix("/") {
            relativePath = String(relativePath.dropFirst())
        }

        if let branch, !branch.isEmpty, relativePath.hasPrefix(branch + "/") {
            relativePath = String(relativePath.dropFirst(branch.count + 1))
        }

        if relativePath.isEmpty {
            return URL(fileURLWithPath: fullPath).lastPathComponent
        }
        return relativePath
    }

    // MARK: - Argument Accessors

    /// Get a string argument by key
    public func string(for key: String) -> String? {
        self.args[key]?.value as? String
    }

    /// Get a string argument with a default value
    public func string(for key: String, default defaultValue: String) -> String {
        (self.args[key]?.value as? String) ?? defaultValue
    }

    /// Get an array of todos (for TodoWrite tool)
    public func todos() -> [TodoItem] {
        guard let todosArray = args["todos"]?.value as? [[String: Any]] else {
            return []
        }
        return todosArray.compactMap { TodoItem.from(dictionary: $0) }
    }

    /// Get delegations (for delegate tool)
    public func delegations() -> [Delegation] {
        guard let delegationsArray = args["delegations"]?.value as? [[String: Any]] else {
            return []
        }
        return delegationsArray.compactMap { Delegation.from(dictionary: $0) }
    }

    // MARK: - Path Helpers

    /// Get a display-friendly path for a file argument
    public func displayPath(for key: String) -> String {
        guard let fullPath = string(for: key) else {
            return ""
        }
        return Self.getDisplayPath(fullPath: fullPath, projectDTag: self.projectDTag, branch: self.branch)
    }

    // MARK: Internal

    // MARK: - Factory

    static func from(event: NDKEvent) -> Self? {
        guard event.kind == 1111,
              let toolName = event.tagValue("tool"),
              !toolName.isEmpty
        else {
            return nil
        }

        let args = self.parseToolArgs(from: event)
        let projectDTag = self.extractProjectDTag(from: event)
        let branch = event.tagValue("branch")

        return Self(
            name: toolName,
            args: args,
            projectDTag: projectDTag,
            branch: branch
        )
    }

    // MARK: Private

    private static func parseToolArgs(from event: NDKEvent) -> [String: AnySendable] {
        guard let toolArgsTag = event.tags(withName: "tool-args").first,
              toolArgsTag.count > 1,
              let jsonData = toolArgsTag[1].data(using: .utf8)
        else {
            return [:]
        }

        do {
            if let dict = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                return dict.mapValues { AnySendable($0) }
            }
        } catch {}
        return [:]
    }

    private static func extractProjectDTag(from event: NDKEvent) -> String? {
        guard let aTag = event.tags(withName: "a").first,
              aTag.count > 1
        else {
            return nil
        }

        let parts = aTag[1].split(separator: ":")
        guard parts.count >= 3 else {
            return nil
        }
        return parts.dropFirst(2).joined(separator: ":")
    }
}

// MARK: - AnySendable

/// Type-erased Sendable wrapper for arbitrary values
public struct AnySendable: @unchecked Sendable {
    // MARK: Lifecycle

    public init(_ value: Any) {
        self.value = value
    }

    // MARK: Public

    public let value: Any
}

// MARK: - TodoItem

/// A todo item from the TodoWrite tool
public struct TodoItem: Sendable {
    // MARK: Public

    public enum Status: String, Sendable {
        case pending
        case inProgress = "in_progress"
        case completed
    }

    public let content: String
    public let status: Status
    public let activeForm: String

    // MARK: Internal

    static func from(dictionary: [String: Any]) -> Self? {
        guard let content = dictionary["content"] as? String,
              let statusString = dictionary["status"] as? String,
              let status = Status(rawValue: statusString)
        else {
            return nil
        }

        let activeForm = dictionary["activeForm"] as? String ?? content
        return Self(content: content, status: status, activeForm: activeForm)
    }
}

// MARK: - Delegation

/// A delegation from the delegate tool
public struct Delegation: Sendable {
    // MARK: Public

    public let recipient: String?
    public let prompt: String?

    // MARK: Internal

    static func from(dictionary: [String: Any]) -> Self? {
        Self(
            recipient: dictionary["recipient"] as? String,
            prompt: dictionary["prompt"] as? String
        )
    }
}

// MARK: - Message

/// Represents a TENEX message (Nostr kind:1111 - GenericReply)
public struct Message: Identifiable, Sendable {
    // MARK: Lifecycle

    /// Initialize a Message
    /// - Parameters:
    ///   - id: The message identifier
    ///   - pubkey: The pubkey of the message author
    ///   - threadId: The thread ID this message belongs to
    ///   - content: The message content
    ///   - createdAt: When the message was created
    ///   - replyTo: Optional parent message ID
    ///   - isStreaming: Whether this is a synthetic streaming message
    ///   - replyCount: Number of replies to this message
    ///   - replyAuthorPubkeys: Pubkeys of reply authors (for avatar display, max 3)
    ///   - toolCall: Optional tool call data if this message represents a tool invocation
    ///   - isReasoning: Whether this message contains AI reasoning/thinking content
    public init(
        id: String,
        pubkey: String,
        threadID: String,
        content: String,
        createdAt: Date,
        replyTo: String?,
        kind: UInt16,
        isStreaming: Bool = false,
        replyCount: Int = 0,
        replyAuthorPubkeys: [String] = [],
        toolCall: ToolCall? = nil,
        isReasoning: Bool = false,
        branch: String? = nil,
        phase: String? = nil,
        pTaggedPubkeys: [String] = [],
        suggestions: [String] = [],
        rawEventJSON: String? = nil,
        projectCoordinate: String? = nil
    ) {
        self.id = id
        self.pubkey = pubkey
        self.threadID = threadID
        self.content = content
        self.createdAt = createdAt
        self.replyTo = replyTo
        self.kind = kind
        self.isStreaming = isStreaming
        self.replyCount = replyCount
        self.replyAuthorPubkeys = replyAuthorPubkeys
        self.toolCall = toolCall
        self.isReasoning = isReasoning
        self.branch = branch
        self.phase = phase
        self.pTaggedPubkeys = pTaggedPubkeys
        self.suggestions = suggestions
        self.rawEventJSON = rawEventJSON
        self.projectCoordinate = projectCoordinate
    }

    // MARK: Public

    /// The message identifier (event ID)
    public let id: String

    /// The pubkey of the message author
    public let pubkey: String

    /// The thread ID this message belongs to (from 'E' tag - root event reference)
    public let threadID: String

    /// The message content (raw markdown)
    public let content: String

    /// When the message was created
    public let createdAt: Date

    /// Optional parent message ID (from 'e' tag for threading)
    public let replyTo: String?

    /// Whether this is a synthetic streaming message (content still being received)
    public let isStreaming: Bool

    /// Number of replies to this message (computed when building display messages)
    public let replyCount: Int

    /// Pubkeys of reply authors for avatar display (max 3, computed when building display messages)
    public let replyAuthorPubkeys: [String]

    /// Tool call data if this message represents a tool invocation
    public let toolCall: ToolCall?

    /// Whether this message contains AI reasoning/thinking content
    public let isReasoning: Bool

    /// Event kind (11 for thread, 1111 for GenericReply)
    public let kind: UInt16

    /// Branch name from event tags
    public let branch: String?

    /// Phase name from event tags
    public let phase: String?

    /// P-tagged pubkeys from event
    public let pTaggedPubkeys: [String]

    /// Suggestion strings from event tags
    public let suggestions: [String]

    /// Raw event JSON for debugging
    public let rawEventJSON: String?

    /// Project coordinate from 'a' tag (e.g., "31933:pubkey:dtag")
    public let projectCoordinate: String?

    /// Whether this message is a tool call
    public var isToolCall: Bool { self.toolCall != nil }

    /// Create a Message from a Nostr event
    /// - Parameter event: The NDKEvent (must be kind:11 or kind:1111)
    /// - Returns: A Message instance, or nil if the event is invalid
    public static func from(event: NDKEvent) -> Self? {
        let metadata = self.extractMetadata(from: event)

        if event.kind == 11 {
            return self.createThreadRoot(from: event, metadata: metadata)
        }

        guard event.kind == 1111 else {
            return nil
        }

        return self.createThreadReply(from: event, metadata: metadata)
    }

    /// Create a filter for fetching messages by thread
    /// - Parameter threadId: The thread identifier (conversation ID)
    /// - Returns: An NDKFilter configured for kind:1111 events with uppercase 'E' tag (root reference)
    public static func filter(for threadID: String) -> NDKFilter {
        NDKFilter(
            kinds: [1111],
            tags: ["e": Set([threadID])]
        )
    }

    /// Create a copy of this message with a new ID
    /// - Parameter id: The new ID
    /// - Returns: A new Message with the updated ID
    public func with(id: String) -> Self {
        Self(
            id: id,
            pubkey: self.pubkey,
            threadID: self.threadID,
            content: self.content,
            createdAt: self.createdAt,
            replyTo: self.replyTo,
            kind: self.kind,
            isStreaming: self.isStreaming,
            replyCount: self.replyCount,
            replyAuthorPubkeys: self.replyAuthorPubkeys,
            toolCall: self.toolCall,
            isReasoning: self.isReasoning,
            branch: self.branch,
            phase: self.phase,
            pTaggedPubkeys: self.pTaggedPubkeys,
            suggestions: self.suggestions,
            rawEventJSON: self.rawEventJSON,
            projectCoordinate: self.projectCoordinate
        )
    }

    /// Create a copy of this message with reply metadata
    /// - Parameters:
    ///   - replyCount: Number of replies
    ///   - replyAuthorPubkeys: Pubkeys of reply authors (max 3)
    /// - Returns: A new Message with the reply metadata
    public func with(replyCount: Int, replyAuthorPubkeys: [String]) -> Self {
        Self(
            id: self.id,
            pubkey: self.pubkey,
            threadID: self.threadID,
            content: self.content,
            createdAt: self.createdAt,
            replyTo: self.replyTo,
            kind: self.kind,
            isStreaming: self.isStreaming,
            replyCount: replyCount,
            replyAuthorPubkeys: replyAuthorPubkeys,
            toolCall: self.toolCall,
            isReasoning: self.isReasoning,
            branch: self.branch,
            phase: self.phase,
            pTaggedPubkeys: self.pTaggedPubkeys,
            suggestions: self.suggestions,
            rawEventJSON: self.rawEventJSON,
            projectCoordinate: self.projectCoordinate
        )
    }

    // MARK: Private

    private struct EventMetadata {
        let createdAt: Date
        let isReasoning: Bool
        let branch: String?
        let phase: String?
        let pTaggedPubkeys: [String]
        let suggestions: [String]
        let rawEventJSON: String?
    }

    private static func createThreadRoot(from event: NDKEvent, metadata: EventMetadata) -> Self {
        Self(
            id: event.id,
            pubkey: event.pubkey,
            threadID: event.id,
            content: event.content,
            createdAt: metadata.createdAt,
            replyTo: nil,
            kind: UInt16(event.kind),
            isReasoning: metadata.isReasoning,
            branch: metadata.branch,
            phase: metadata.phase,
            pTaggedPubkeys: metadata.pTaggedPubkeys,
            suggestions: metadata.suggestions,
            rawEventJSON: metadata.rawEventJSON,
            projectCoordinate: event.tagValue("a")
        )
    }

    private static func createThreadReply(from event: NDKEvent, metadata: EventMetadata) -> Self? {
        let threadID: String
        if let ETag = event.tagValue("E"), !ETag.isEmpty {
            threadID = ETag
        } else if let eTag = event.tagValue("e"), !eTag.isEmpty {
            threadID = eTag
        } else {
            return nil
        }

        return Self(
            id: event.id,
            pubkey: event.pubkey,
            threadID: threadID,
            content: event.content,
            createdAt: metadata.createdAt,
            replyTo: event.tagValue("e"),
            kind: UInt16(event.kind),
            toolCall: ToolCall.from(event: event),
            isReasoning: metadata.isReasoning,
            branch: metadata.branch,
            phase: metadata.phase,
            pTaggedPubkeys: metadata.pTaggedPubkeys,
            suggestions: metadata.suggestions,
            rawEventJSON: metadata.rawEventJSON,
            projectCoordinate: event.tagValue("a")
        )
    }

    private static func extractMetadata(from event: NDKEvent) -> EventMetadata {
        let createdAt = Date(timeIntervalSince1970: TimeInterval(event.createdAt))
        let isReasoning = event.tags(withName: "reasoning").first != nil
        let branch = event.tags(withName: "branch").first?[safe: 1]
        let phase = event.tags(withName: "phase").first?[safe: 1]
        let pTaggedPubkeys = event.tags(withName: "p").compactMap { $0[safe: 1] }
        let suggestions = event.tags(withName: "suggestion").compactMap { $0[safe: 1] }

        let eventDict: [String: Any] = [
            "id": event.id,
            "pubkey": event.pubkey,
            "created_at": event.createdAt,
            "kind": event.kind,
            "content": event.content,
            "sig": event.sig,
            "tags": event.tags.map { Array($0) },
        ]
        let rawEventJSON: String? = if let jsonData = try? JSONSerialization.data(
            withJSONObject: eventDict,
            options: .prettyPrinted
        ),
            let jsonString = String(data: jsonData, encoding: .utf8) {
            jsonString
        } else {
            nil
        }

        return EventMetadata(
            createdAt: createdAt,
            isReasoning: isReasoning,
            branch: branch,
            phase: phase,
            pTaggedPubkeys: pTaggedPubkeys,
            suggestions: suggestions,
            rawEventJSON: rawEventJSON
        )
    }
}
