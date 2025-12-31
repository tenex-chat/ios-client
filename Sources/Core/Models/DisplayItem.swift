//
// DisplayItem.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation

// MARK: - DisplayItem

/// Represents an item in the display model for chat messages
/// Groups consecutive messages from the same author
public enum DisplayItem: Identifiable, Sendable {
    /// A single message (when not part of a consecutive group)
    case visible(VisibleItem)

    /// A group of consecutive messages from the same author
    case agentGroup(AgentGroupItem)

    /// Metadata event (phase changes, etc.)
    case metadata(MetadataItem)

    // MARK: Public

    public var id: String {
        switch self {
        case let .visible(item):
            item.id
        case let .agentGroup(item):
            item.id
        case let .metadata(item):
            item.id
        }
    }
}

// MARK: - VisibleItem

/// A single visible message item
public struct VisibleItem: Identifiable, Sendable {
    public let message: Message
    public let isConsecutive: Bool

    public var id: String { self.message.id }

    public init(
        message: Message,
        isConsecutive: Bool = false
    ) {
        self.message = message
        self.isConsecutive = isConsecutive
    }
}

// MARK: - AgentGroupItem

/// A group of consecutive messages from the same author
/// Replaces the old ToolGroupItem - now groups ALL message types together
public struct AgentGroupItem: Identifiable, Sendable {
    /// All messages in this group (tools, reasoning, regular - all mixed together)
    public let messages: [Message]

    /// Whether this continues from the previous message by the same author
    public let isConsecutive: Bool

    public var id: String {
        "agent_group-\(messages.first?.id ?? UUID().uuidString)"
    }

    /// The pubkey of the author (all messages in group have same pubkey)
    public var pubkey: String? {
        messages.first?.pubkey
    }

    public init(
        messages: [Message],
        isConsecutive: Bool = false
    ) {
        self.messages = messages
        self.isConsecutive = isConsecutive
    }
}

// MARK: - MetadataItem

/// A metadata item (phase changes, etc.)
public struct MetadataItem: Identifiable, Sendable {
    public let message: Message

    public var id: String { "metadata-\(message.id)" }

    public init(message: Message) {
        self.message = message
    }
}

// MARK: - DisplayModelBuilder

/// Builds display items from messages
/// Groups consecutive messages from the same author together
public enum DisplayModelBuilder {
    // MARK: Public

    /// Create a display model from messages
    /// Groups consecutive messages from the same author (no p-tag interruption)
    public static func createDisplayModel(from messages: [Message]) -> [DisplayItem] {
        var items: [DisplayItem] = []
        var currentGroup: [Message] = []
        var lastPubkey: String?
        var groupStartIsConsecutive = false

        for message in messages {
            let isConsecutive = message.pubkey == lastPubkey && message.pTaggedPubkeys.isEmpty

            // Metadata stays separate
            if message.phase != nil, message.content.isEmpty {
                finalizeGroup(&currentGroup, into: &items, isConsecutive: groupStartIsConsecutive)
                items.append(.metadata(MetadataItem(message: message)))
                groupStartIsConsecutive = false
            }
            // Check if this message breaks the current group
            else if !currentGroup.isEmpty, !isConsecutive {
                finalizeGroup(&currentGroup, into: &items, isConsecutive: groupStartIsConsecutive)
                currentGroup = [message]
                groupStartIsConsecutive = isConsecutive
            }
            // Add to current group
            else {
                if currentGroup.isEmpty {
                    groupStartIsConsecutive = isConsecutive
                }
                currentGroup.append(message)
            }

            lastPubkey = message.pubkey
        }

        // Finalize remaining group
        finalizeGroup(&currentGroup, into: &items, isConsecutive: groupStartIsConsecutive)

        return items
    }

    // MARK: Private

    private static func finalizeGroup(
        _ group: inout [Message],
        into items: inout [DisplayItem],
        isConsecutive: Bool
    ) {
        guard !group.isEmpty else {
            return
        }

        if group.count == 1 {
            // Single message → VisibleItem
            items.append(.visible(VisibleItem(message: group[0], isConsecutive: isConsecutive)))
        } else {
            // Multiple messages → AgentGroupItem
            items.append(.agentGroup(AgentGroupItem(messages: group, isConsecutive: isConsecutive)))
        }

        group = []
    }
}
