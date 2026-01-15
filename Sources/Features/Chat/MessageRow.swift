//
// MessageRow.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import NDKSwiftCore
import NDKSwiftUI
import SwiftUI
import TENEXCore

// MARK: - MessageRow

/// View displaying a single message in Slack-style left-aligned layout
public struct MessageRow: View {
    // MARK: Lifecycle

    public init(
        message: Message,
        currentUserPubkey: String?,
        isConsecutive: Bool = false,
        isAskAnswered: Bool = false,
        askAnswerContent: String? = nil,
        onReplyTap: (() -> Void)? = nil,
        onAgentTap: (() -> Void)? = nil,
        onQuote: (() -> Void)? = nil,
        onTimestampTap: (() -> Void)? = nil,
        onPlayTTS: (() -> Void)? = nil,
        onSuggestionTap: ((String) -> Void)? = nil,
        onSendInNewConversation: (() -> Void)? = nil,
        onAskAnswer: (([String: [String]]) -> Void)? = nil,
        showDebugInfo: Bool = false
    ) {
        self.message = message
        self.currentUserPubkey = currentUserPubkey
        self.isConsecutive = isConsecutive
        self.isAskAnswered = isAskAnswered
        self.askAnswerContent = askAnswerContent
        self.onReplyTap = onReplyTap
        self.onAgentTap = onAgentTap
        self.onQuote = onQuote
        self.onTimestampTap = onTimestampTap
        self.onPlayTTS = onPlayTTS
        self.onSuggestionTap = onSuggestionTap
        self.onSendInNewConversation = onSendInNewConversation
        self.onAskAnswer = onAskAnswer
        self.showDebugInfo = showDebugInfo
        self.isAgent = currentUserPubkey != nil && message.pubkey != currentUserPubkey
    }

    // MARK: Public

    public var body: some View {
        self.messageContent
            .padding(.vertical, self.isConsecutive ? 2 : 8)
            .contextMenu {
                self.contextMenuContent
            }
            .sheet(isPresented: self.$showRawEvent) {
                RawEventSheet(rawEventJSON: self.message.rawEventJSON, isPresented: self.$showRawEvent)
            }
            .sheet(isPresented: self.$showLLMMetadata) {
                LLMMetadataSheet(
                    isPresented: self.$showLLMMetadata,
                    metadata: LLMMetadata.from(rawEventJSON: self.message.rawEventJSON)
                )
            }
    }

    // MARK: Private

    @Environment(\.ndk) private var ndk
    @State private var showRawEvent = false
    @State private var showLLMMetadata = false

    private let message: Message
    private let currentUserPubkey: String?
    private let isConsecutive: Bool
    private let isAskAnswered: Bool
    private let askAnswerContent: String?
    private let onReplyTap: (() -> Void)?
    private let onAgentTap: (() -> Void)?
    private let onQuote: (() -> Void)?
    private let onTimestampTap: (() -> Void)?
    private let onPlayTTS: (() -> Void)?
    private let onSuggestionTap: ((String) -> Void)?
    private let onSendInNewConversation: (() -> Void)?
    private let onAskAnswer: (([String: [String]]) -> Void)?
    private let showDebugInfo: Bool
    private let isAgent: Bool

    private var messageContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            if !self.isConsecutive {
                MessageHeaderView(
                    message: self.message,
                    currentUserPubkey: self.currentUserPubkey,
                    showDebugInfo: self.showDebugInfo,
                    onAgentTap: self.onAgentTap,
                    onTimestampTap: self.onTimestampTap
                )
            }

            MessageContentView(
                message: self.message,
                isAskAnswered: self.isAskAnswered,
                askAnswerContent: self.askAnswerContent,
                onAskAnswer: self.onAskAnswer
            )

            if self.message.replyCount > 0, let onReplyTap, let ndk {
                ReplyIndicatorView(
                    ndk: ndk,
                    replyCount: self.message.replyCount,
                    authorPubkeys: self.message.replyAuthorPubkeys,
                    onTap: onReplyTap
                )
                .padding(.top, 4)
            }

            if !self.message.suggestions.isEmpty {
                self.suggestionsView
            }
        }
    }

    private var suggestionsView: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(self.message.suggestions, id: \.self) { suggestion in
                Button {
                    self.onSuggestionTap?(suggestion)
                } label: {
                    Text(suggestion)
                        .font(.subheadline)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 8)
    }

    @ViewBuilder private var contextMenuContent: some View {
        if let onReplyTap {
            Button {
                onReplyTap()
            } label: {
                Label("Reply", systemImage: "arrowshape.turn.up.left")
            }
        }

        if let onQuote {
            Button {
                onQuote()
            } label: {
                Label("Quote", systemImage: "quote.bubble")
            }
        }

        if let onPlayTTS {
            Button {
                onPlayTTS()
            } label: {
                Label("Play Audio", systemImage: "speaker.wave.2.fill")
            }
        }

        if let onSendInNewConversation {
            Button {
                onSendInNewConversation()
            } label: {
                Label("Send in New Conversation", systemImage: "plus.message")
            }
        }

        Button {
            self.copyToClipboard(self.message.content)
        } label: {
            Label("Copy Content", systemImage: "doc.on.doc")
        }

        if let rawEventJSON = message.rawEventJSON {
            Button {
                self.copyToClipboard(rawEventJSON)
            } label: {
                Label("Copy Raw Event", systemImage: "doc.on.doc.fill")
            }
        }

        Button {
            self.copyToClipboard(self.message.id)
        } label: {
            Label("Copy ID", systemImage: "number")
        }

        if self.message.rawEventJSON != nil {
            Button {
                self.showRawEvent = true
            } label: {
                Label("View Raw Event", systemImage: "chevron.left.forwardslash.chevron.right")
            }

            Button {
                self.showLLMMetadata = true
            } label: {
                Label("View LLM Metadata", systemImage: "cpu")
            }
        }
    }

    private func copyToClipboard(_ text: String) {
        #if os(iOS)
            UIPasteboard.general.string = text
        #else
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
        #endif
    }
}
