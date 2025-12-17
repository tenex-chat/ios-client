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
        hasNextConsecutive: Bool = false,
        onReplyTap: (() -> Void)? = nil,
        onAgentTap: (() -> Void)? = nil,
        onQuote: (() -> Void)? = nil,
        onTimestampTap: (() -> Void)? = nil,
        onPlayTTS: (() -> Void)? = nil,
        showDebugInfo: Bool = false
    ) {
        self.message = message
        self.currentUserPubkey = currentUserPubkey
        self.isConsecutive = isConsecutive
        self.hasNextConsecutive = hasNextConsecutive
        self.onReplyTap = onReplyTap
        self.onAgentTap = onAgentTap
        self.onQuote = onQuote
        self.onTimestampTap = onTimestampTap
        self.onPlayTTS = onPlayTTS
        self.showDebugInfo = showDebugInfo
        self.isAgent = currentUserPubkey != nil && message.pubkey != currentUserPubkey
    }

    // MARK: Public

    public var body: some View {
        HStack(alignment: .top, spacing: 12) {
            self.avatarColumnView
            self.messageContent
            Spacer()
        }
        .padding(.vertical, self.isConsecutive ? 2 : 8)
        .contextMenu {
            self.contextMenuContent
        }
        .sheet(isPresented: self.$showRawEvent) {
            RawEventSheet(rawEventJSON: self.message.rawEventJSON, isPresented: self.$showRawEvent)
        }
    }

    // MARK: Private

    @Environment(\.ndk) private var ndk
    @State private var showRawEvent = false

    private let message: Message
    private let currentUserPubkey: String?
    private let isConsecutive: Bool
    private let hasNextConsecutive: Bool
    private let onReplyTap: (() -> Void)?
    private let onAgentTap: (() -> Void)?
    private let onQuote: (() -> Void)?
    private let onTimestampTap: (() -> Void)?
    private let onPlayTTS: (() -> Void)?
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

            MessageContentView(message: self.message)

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

    private var avatarColumnView: some View {
        VStack(spacing: 0) {
            if self.isConsecutive {
                self.threadContinuityLine
            } else {
                self.avatarView
            }
            if self.hasNextConsecutive {
                self.threadContinuityLineBelow
            }
        }
        .frame(width: 36)
    }

    private var threadContinuityLine: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 2)
                .frame(maxHeight: .infinity)
            Circle()
                .fill(Color.gray.opacity(0.5))
                .frame(width: 8, height: 8)
        }
        .frame(height: 20)
    }

    private var threadContinuityLineBelow: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.3))
            .frame(width: 2)
            .frame(maxHeight: .infinity)
    }

    private var avatarView: some View {
        Group {
            if self.isAgent, let onAgentTap {
                Button(action: onAgentTap) {
                    self.avatar
                }
                .buttonStyle(.plain)
            } else {
                self.avatar
            }
        }
    }

    @ViewBuilder private var avatar: some View {
        if let ndk {
            NDKUIProfilePicture(ndk: ndk, pubkey: self.message.pubkey, size: 36)
        } else {
            Image(systemName: "person.circle.fill")
                .font(.largeTitle)
                .foregroundStyle(self.isAgent ? .blue : .gray)
        }
    }

    private var suggestionsView: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(self.message.suggestions, id: \.self) { suggestion in
                Button {} label: {
                    Text(suggestion)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(4)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 4)
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
