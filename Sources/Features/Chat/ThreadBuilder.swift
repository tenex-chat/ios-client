//
// ThreadBuilder.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation
import TENEXCore

// MARK: - ThreadNode

/// A node in the thread tree representing a message and its replies
public struct ThreadNode: Identifiable {
    // MARK: Lifecycle

    /// Initialize a thread node
    /// - Parameters:
    ///   - message: The message at this node
    ///   - replies: Direct replies to this message
    public init(message: Message, replies: [Self]) {
        self.message = message
        self.replies = replies
    }

    // MARK: Public

    /// The message at this node
    public let message: Message

    /// Direct replies to this message
    public let replies: [Self]

    /// Unique identifier (uses message ID)
    public var id: String {
        message.id
    }
}

// MARK: - ThreadBuilder

/// Builds a thread tree from a flat list of messages
public enum ThreadBuilder {
    // MARK: Public

    /// Build a thread tree from a flat list of messages
    /// - Parameter messages: The flat list of messages
    /// - Returns: A tree structure of thread nodes (roots)
    public static func buildTree(from messages: [Message]) -> [ThreadNode] {
        // Group messages by their parent ID
        var messagesByParent: [String?: [Message]] = [:]
        var messagesByID: [String: Message] = [:]

        for message in messages {
            messagesByID[message.id] = message
            messagesByParent[message.replyTo, default: []].append(message)
        }

        // Sort each group chronologically
        for (parent, msgs) in messagesByParent {
            messagesByParent[parent] = msgs.sorted { $0.createdAt < $1.createdAt }
        }

        // Build tree starting from roots (messages with no parent or orphaned)
        let roots = messages
            .filter { message in
                guard let replyTo = message.replyTo else {
                    return true
                }
                return messagesByID[replyTo] == nil
            }
            .sorted { $0.createdAt < $1.createdAt }

        return roots.map { Self.buildNode(for: $0, messagesByParent: messagesByParent, depth: 1) }
    }

    // MARK: Private

    /// Maximum depth for thread nesting
    private static let maxDepth = 5

    /// Build a node and its children recursively
    /// - Parameters:
    ///   - message: The message for this node
    ///   - messagesByParent: Messages grouped by parent ID
    ///   - depth: Current depth in the tree
    /// - Returns: A thread node with its replies
    private static func buildNode(
        for message: Message,
        messagesByParent: [String?: [Message]],
        depth: Int
    ) -> ThreadNode {
        // If we've reached max depth, flatten all descendants
        if depth >= maxDepth {
            let descendants = Self.getAllDescendants(
                of: message.id,
                messagesByParent: messagesByParent
            )
            let descendantNodes = descendants.map { ThreadNode(message: $0, replies: []) }
            return ThreadNode(message: message, replies: descendantNodes)
        }

        // Build replies recursively
        let children = messagesByParent[message.id] ?? []
        let childNodes = children.map {
            Self.buildNode(for: $0, messagesByParent: messagesByParent, depth: depth + 1)
        }
        return ThreadNode(message: message, replies: childNodes)
    }

    /// Get all descendants of a message (for flattening at max depth)
    /// - Parameters:
    ///   - messageId: The message ID
    ///   - messagesByParent: Messages grouped by parent ID
    /// - Returns: All descendant messages in chronological order
    private static func getAllDescendants(
        of messageID: String,
        messagesByParent: [String?: [Message]]
    ) -> [Message] {
        var result: [Message] = []
        var queue = messagesByParent[messageID] ?? []

        while !queue.isEmpty {
            let message = queue.removeFirst()
            result.append(message)

            let children = messagesByParent[message.id] ?? []
            queue.append(contentsOf: children)
        }

        return result.sorted { $0.createdAt < $1.createdAt }
    }
}
