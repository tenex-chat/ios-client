//
// AgentMessageGroupView.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import SwiftUI
import TENEXCore

// MARK: - AgentMessageGroupView

/// View that displays a group of consecutive messages from the same author
/// Shows first message, aggregated todos, collapsed middle messages, and last 2 messages
struct AgentMessageGroupView: View {
    // MARK: Lifecycle

    init(
        item: AgentGroupItem,
        currentUserPubkey: String?,
        onReplyTap: ((Message) -> Void)? = nil,
        onAgentTap: ((Message) -> Void)? = nil,
        onQuote: ((Message) -> Void)? = nil,
        onTimestampTap: ((Message) -> Void)? = nil,
        onPlayTTS: ((Message) -> Void)? = nil,
        onSuggestionTap: ((String) -> Void)? = nil,
        onSendInNewConversation: ((Message) -> Void)? = nil,
        askAnswerLookup: ((String) -> Message?)? = nil,
        onAskAnswer: ((Message, [String: [String]]) -> Void)? = nil,
        showDebugInfo: Bool = false
    ) {
        self.item = item
        self.currentUserPubkey = currentUserPubkey
        self.onReplyTap = onReplyTap
        self.onAgentTap = onAgentTap
        self.onQuote = onQuote
        self.onTimestampTap = onTimestampTap
        self.onPlayTTS = onPlayTTS
        self.onSuggestionTap = onSuggestionTap
        self.onSendInNewConversation = onSendInNewConversation
        self.askAnswerLookup = askAnswerLookup
        self.onAskAnswer = onAskAnswer
        self.showDebugInfo = showDebugInfo
    }

    // MARK: Internal

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // First message (always visible)
            messageRow(for: firstMessage, isConsecutive: item.isConsecutive)

            // Aggregated todos (if any)
            if !todos.isEmpty {
                AgentTodoListView(todos: todos)
            }

            // Collapse/expand for middle messages
            if !middleMessages.isEmpty {
                CollapsedMessagesView(messages: middleMessages, isExpanded: $isExpanded)

                if isExpanded {
                    ForEach(middleMessages) { message in
                        messageRow(for: message, isConsecutive: true)
                    }
                }
            }

            // Last 2 messages (always visible)
            ForEach(Array(lastMessages.enumerated()), id: \.element.id) { _, message in
                messageRow(for: message, isConsecutive: true)
            }
        }
    }

    // MARK: Private

    private static let lastVisibleCount = 2

    @State private var isExpanded = false

    private let item: AgentGroupItem
    private let currentUserPubkey: String?
    private let onReplyTap: ((Message) -> Void)?
    private let onAgentTap: ((Message) -> Void)?
    private let onQuote: ((Message) -> Void)?
    private let onTimestampTap: ((Message) -> Void)?
    private let onPlayTTS: ((Message) -> Void)?
    private let onSuggestionTap: ((String) -> Void)?
    private let onSendInNewConversation: ((Message) -> Void)?
    private let askAnswerLookup: ((String) -> Message?)?
    private let onAskAnswer: ((Message, [String: [String]]) -> Void)?
    private let showDebugInfo: Bool

    private var firstMessage: Message {
        item.messages[0]
    }

    private var lastMessages: [Message] {
        guard item.messages.count > Self.lastVisibleCount else {
            // If 2 or fewer messages, show all except first as "last"
            return Array(item.messages.dropFirst())
        }
        return Array(item.messages.suffix(Self.lastVisibleCount))
    }

    private var middleMessages: [Message] {
        guard item.messages.count > Self.lastVisibleCount + 1 else {
            // No middle messages if 3 or fewer total
            return []
        }
        return Array(item.messages.dropFirst().dropLast(Self.lastVisibleCount))
    }

    private var todos: [TodoItem] {
        TodoAggregator.aggregate(from: item.messages)
    }

    @ViewBuilder
    private func messageRow(
        for message: Message,
        isConsecutive: Bool
    ) -> some View {
        let askAnswer = message.isAskEvent ? askAnswerLookup?(message.id) : nil

        MessageRow(
            message: message,
            currentUserPubkey: currentUserPubkey,
            isConsecutive: isConsecutive,
            isAskAnswered: askAnswer != nil,
            askAnswerContent: askAnswer?.content,
            onReplyTap: onReplyTap.map { callback in { callback(message) } },
            onAgentTap: onAgentTap.map { callback in { callback(message) } },
            onQuote: onQuote.map { callback in { callback(message) } },
            onTimestampTap: onTimestampTap.map { callback in { callback(message) } },
            onPlayTTS: onPlayTTS.map { callback in { callback(message) } },
            onSuggestionTap: onSuggestionTap,
            onSendInNewConversation: onSendInNewConversation.map { callback in { callback(message) } },
            onAskAnswer: askAnswer == nil
                ? onAskAnswer.map { callback in { responses in callback(message, responses) } }
                : nil,
            showDebugInfo: showDebugInfo
        )
    }
}
