//
// DisplayItem.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation

// MARK: - DisplayItem

/// Represents an item in the display model for chat messages
/// This enum enables grouping of sequential tool calls with their associated thinking blocks
public enum DisplayItem: Identifiable, Sendable {
    /// A visible message to display (user messages, AI responses with content)
    case visible(VisibleItem)

    /// A group of sequential tool calls with optional thinking blocks
    case toolGroup(ToolGroupItem)

    /// Metadata event (phase changes, etc.)
    case metadata(MetadataItem)

    // MARK: Public

    public var id: String {
        switch self {
        case let .visible(item):
            item.id
        case let .toolGroup(item):
            item.id
        case let .metadata(item):
            item.id
        }
    }
}

// MARK: - VisibleItem

/// A visible message item
public struct VisibleItem: Identifiable, Sendable {
    public let message: Message
    public let isConsecutive: Bool
    public let hasNextConsecutive: Bool
    public let isLastReasoningMessage: Bool

    public var id: String { self.message.id }

    public init(
        message: Message,
        isConsecutive: Bool = false,
        hasNextConsecutive: Bool = false,
        isLastReasoningMessage: Bool = false
    ) {
        self.message = message
        self.isConsecutive = isConsecutive
        self.hasNextConsecutive = hasNextConsecutive
        self.isLastReasoningMessage = isLastReasoningMessage
    }
}

// MARK: - ToolGroupItem

/// A group of tool calls with optional thinking blocks
public struct ToolGroupItem: Identifiable, Sendable {
    /// The tool call messages in this group
    public let tools: [Message]

    /// Associated thinking/reasoning messages
    public let thinking: [Message]

    /// Whether this group is currently active (last group with no messages after)
    public let isActive: Bool

    /// Whether this continues from the previous message by the same author
    public let isConsecutive: Bool

    /// Whether the next message is from the same author
    public let hasNextConsecutive: Bool

    public var id: String {
        // Use first tool's ID, or first thinking message ID for thinking-only groups
        "tool_group-\(tools.first?.id ?? thinking.first?.id ?? "empty")"
    }

    /// All tool calls from the messages
    public var toolCalls: [ToolCall] {
        self.tools.compactMap(\.toolCall)
    }

    /// Whether this group has thinking content
    public var hasThinking: Bool {
        !self.thinking.isEmpty
    }

    public init(
        tools: [Message],
        thinking: [Message] = [],
        isActive: Bool = false,
        isConsecutive: Bool = false,
        hasNextConsecutive: Bool = false
    ) {
        self.tools = tools
        self.thinking = thinking
        self.isActive = isActive
        self.isConsecutive = isConsecutive
        self.hasNextConsecutive = hasNextConsecutive
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

/// Builds display items from messages with tool grouping logic
public enum DisplayModelBuilder {
    // MARK: Public

    /// Create a display model from messages
    /// Groups sequential tool calls together with their associated thinking blocks
    public static func createDisplayModel(from messages: [Message]) -> [DisplayItem] {
        var state = BuilderState()

        for (index, message) in messages.enumerated() {
            processMessage(message, at: index, in: messages, state: &state)
        }

        // Finalize any remaining tool group (this one is active)
        finalizeToolGroup(state: &state, isActive: true, nextMessagePubkey: nil)

        return state.items
    }

    // MARK: Private

    private struct BuilderState {
        var items: [DisplayItem] = []
        var currentToolGroup: [Message] = []
        var currentThinking: [Message] = []
        var lastPubkey: String?
    }

    private static func processMessage(
        _ message: Message,
        at index: Int,
        in messages: [Message],
        state: inout BuilderState
    ) {
        let nextMessage = index + 1 < messages.count ? messages[index + 1] : nil
        let isConsecutive = message.pubkey == state.lastPubkey && message.pTaggedPubkeys.isEmpty
        let hasNextConsecutive = nextMessage?.pubkey == message.pubkey &&
            nextMessage?.pTaggedPubkeys.isEmpty == true

        if message.isReasoning {
            state.currentThinking.append(message)
        } else if message.isToolCall {
            state.currentToolGroup.append(message)
        } else {
            finalizeToolGroup(state: &state, isActive: false, nextMessagePubkey: message.pubkey)
            appendVisibleOrMetadata(
                message,
                isConsecutive: isConsecutive,
                hasNextConsecutive: hasNextConsecutive,
                state: &state
            )
        }

        state.lastPubkey = message.pubkey
    }

    private static func finalizeToolGroup(state: inout BuilderState, isActive: Bool, nextMessagePubkey: String?) {
        guard !state.currentToolGroup.isEmpty || !state.currentThinking.isEmpty else {
            return
        }

        let groupPubkey = state.currentToolGroup.last?.pubkey ?? state.currentThinking.last?.pubkey
        let toolGroup = ToolGroupItem(
            tools: state.currentToolGroup,
            thinking: state.currentThinking,
            isActive: isActive,
            isConsecutive: !state.items.isEmpty && state.lastPubkey == state.currentToolGroup.first?.pubkey,
            hasNextConsecutive: nextMessagePubkey == groupPubkey
        )
        state.items.append(.toolGroup(toolGroup))
        state.currentToolGroup = []
        state.currentThinking = []
    }

    private static func appendVisibleOrMetadata(
        _ message: Message,
        isConsecutive: Bool,
        hasNextConsecutive: Bool,
        state: inout BuilderState
    ) {
        if message.phase != nil, message.content.isEmpty {
            state.items.append(.metadata(MetadataItem(message: message)))
        } else {
            let visibleItem = VisibleItem(
                message: message,
                isConsecutive: isConsecutive,
                hasNextConsecutive: hasNextConsecutive,
                isLastReasoningMessage: false
            )
            state.items.append(.visible(visibleItem))
        }
    }
}
