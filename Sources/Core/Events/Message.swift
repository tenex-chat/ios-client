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
        args[key]?.value as? String
    }

    /// Get a string argument with a default value
    public func string(for key: String, default defaultValue: String) -> String {
        (args[key]?.value as? String) ?? defaultValue
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
        return Self.getDisplayPath(fullPath: fullPath, projectDTag: projectDTag, branch: branch)
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

        let args = parseToolArgs(from: event)
        let projectDTag = extractProjectDTag(from: event)
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
    ///   - status: The status of the message
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
        status: MessageStatus? = nil,
        isStreaming: Bool = false,
        replyCount: Int = 0,
        replyAuthorPubkeys: [String] = [],
        toolCall: ToolCall? = nil,
        isReasoning: Bool = false
    ) {
        self.id = id
        self.pubkey = pubkey
        self.threadID = threadID
        self.content = content
        self.createdAt = createdAt
        self.replyTo = replyTo
        self.status = status
        self.isStreaming = isStreaming
        self.replyCount = replyCount
        self.replyAuthorPubkeys = replyAuthorPubkeys
        self.toolCall = toolCall
        self.isReasoning = isReasoning
    }

    // MARK: Public

    /// The message identifier (event ID or temporary ID for optimistic messages)
    public let id: String

    /// The pubkey of the message author
    public let pubkey: String

    /// The thread ID this message belongs to
    public let threadID: String

    /// The message content (raw markdown)
    public let content: String

    /// When the message was created
    public let createdAt: Date

    /// Optional parent message ID (from 'e' tag for threading)
    public let replyTo: String?

    /// The status of the message (for optimistic UI updates)
    public let status: MessageStatus?

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

    /// Whether this message is a tool call
    public var isToolCall: Bool { toolCall != nil }

    /// Create a Message from a Nostr event
    /// - Parameter event: The NDKEvent (must be kind:11 or kind:1111)
    /// - Returns: A Message instance, or nil if the event is invalid
    public static func from(event: NDKEvent) -> Self? {
        // Handle kind:11 (thread event - the original post)
        if event.kind == 11 {
            // For kind:11, the thread ID is the event's own ID
            // and there's no parent (replyTo is nil)
            let createdAt = Date(timeIntervalSince1970: TimeInterval(event.createdAt))
            let isReasoning = event.tags(withName: "reasoning").first != nil

            return Self(
                id: event.id,
                pubkey: event.pubkey,
                threadID: event.id,
                content: event.content,
                createdAt: createdAt,
                replyTo: nil,
                status: nil,
                isReasoning: isReasoning
            )
        }

        // Handle kind:1111 (GenericReply - replies to the thread)
        guard event.kind == 1111 else {
            return nil
        }

        // Extract thread ID from 'a' tag (required for replies)
        guard let aTag = event.tags(withName: "a").first,
              aTag.count > 1,
              !aTag[1].isEmpty
        else {
            return nil
        }
        let threadID = aTag[1]

        // Extract optional parent message ID from 'e' tag
        let replyTo = event.tags(withName: "e").first?[safe: 1]

        // Convert timestamp to Date
        let createdAt = Date(timeIntervalSince1970: TimeInterval(event.createdAt))

        // Parse tool call data if present
        let toolCall = ToolCall.from(event: event)

        // Check if this is a reasoning message
        let isReasoning = event.tags(withName: "reasoning").first != nil

        return Self(
            id: event.id,
            pubkey: event.pubkey,
            threadID: threadID,
            content: event.content,
            createdAt: createdAt,
            replyTo: replyTo,
            status: nil,
            toolCall: toolCall,
            isReasoning: isReasoning
        )
    }

    /// Create a filter for fetching messages by thread
    /// - Parameter threadId: The thread identifier (conversation ID)
    /// - Returns: An NDKFilter configured for kind:1111 events with uppercase 'E' tag (root reference)
    public static func filter(for threadID: String) -> NDKFilter {
        NDKFilter(
            kinds: [1111],
            tags: ["E": Set([threadID])]
        )
    }

    /// Create a copy of this message with a new status
    /// - Parameter status: The new status
    /// - Returns: A new Message with the updated status
    public func with(status: MessageStatus?) -> Self {
        Self(
            id: id,
            pubkey: pubkey,
            threadID: threadID,
            content: content,
            createdAt: createdAt,
            replyTo: replyTo,
            status: status,
            isStreaming: isStreaming,
            replyCount: replyCount,
            replyAuthorPubkeys: replyAuthorPubkeys,
            toolCall: toolCall,
            isReasoning: isReasoning
        )
    }

    /// Create a copy of this message with a new ID
    /// - Parameter id: The new ID
    /// - Returns: A new Message with the updated ID
    public func with(id: String) -> Self {
        Self(
            id: id,
            pubkey: pubkey,
            threadID: threadID,
            content: content,
            createdAt: createdAt,
            replyTo: replyTo,
            status: status,
            isStreaming: isStreaming,
            replyCount: replyCount,
            replyAuthorPubkeys: replyAuthorPubkeys,
            toolCall: toolCall,
            isReasoning: isReasoning
        )
    }

    /// Create a copy of this message with reply metadata
    /// - Parameters:
    ///   - replyCount: Number of replies
    ///   - replyAuthorPubkeys: Pubkeys of reply authors (max 3)
    /// - Returns: A new Message with the reply metadata
    public func with(replyCount: Int, replyAuthorPubkeys: [String]) -> Self {
        Self(
            id: id,
            pubkey: pubkey,
            threadID: threadID,
            content: content,
            createdAt: createdAt,
            replyTo: replyTo,
            status: status,
            isStreaming: isStreaming,
            replyCount: replyCount,
            replyAuthorPubkeys: replyAuthorPubkeys,
            toolCall: toolCall,
            isReasoning: isReasoning
        )
    }
}
