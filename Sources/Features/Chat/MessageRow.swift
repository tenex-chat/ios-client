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
        onReplySwipe: (() -> Void)? = nil,
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
        self.onReplySwipe = onReplySwipe
        self.showDebugInfo = showDebugInfo
        isAgent = currentUserPubkey != nil && message.pubkey != currentUserPubkey
    }

    // MARK: Public

    public var body: some View {
        HStack(alignment: .top, spacing: 12) {
            replyIconView
            avatarColumnView
            messageContent
            Spacer()
        }
        .offset(x: dragOffset)
        .gesture(swipeGesture)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: dragOffset)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isDragging)
        .padding(.vertical, isConsecutive ? 2 : 8)
        .contextMenu {
            contextMenuContent
        }
        .sheet(isPresented: $showRawEvent) {
            RawEventSheet(rawEventJSON: message.rawEventJSON, isPresented: $showRawEvent)
        }
    }

    // MARK: Private

    @Environment(\.ndk) private var ndk
    @State private var showRawEvent = false
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging = false

    private let message: Message
    private let currentUserPubkey: String?
    private let isConsecutive: Bool
    private let hasNextConsecutive: Bool
    private let onReplyTap: (() -> Void)?
    private let onAgentTap: (() -> Void)?
    private let onQuote: (() -> Void)?
    private let onTimestampTap: (() -> Void)?
    private let onReplySwipe: (() -> Void)?
    private let showDebugInfo: Bool
    private let isAgent: Bool

    private var swipeGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                guard onReplySwipe != nil else {
                    return
                }
                // Only activate if horizontal swipe is dominant (not vertical scrolling)
                let horizontalAmount = abs(value.translation.width)
                let verticalAmount = abs(value.translation.height)

                if horizontalAmount > verticalAmount,
                   value.translation.width > 0,
                   value.translation.width < 100 {
                    dragOffset = value.translation.width
                    isDragging = true
                }
            }
            .onEnded { value in
                guard onReplySwipe != nil else {
                    return
                }
                let horizontalAmount = abs(value.translation.width)
                let verticalAmount = abs(value.translation.height)

                if horizontalAmount > verticalAmount, value.translation.width > 50 {
                    onReplySwipe?()
                }
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    dragOffset = 0
                    isDragging = false
                }
            }
    }

    @ViewBuilder private var replyIconView: some View {
        if isDragging, dragOffset > 50 {
            Image(systemName: "arrowshape.turn.up.left")
                .font(.system(size: 20))
                .foregroundStyle(.blue)
                .transition(.scale.combined(with: .opacity))
        }
    }

    private var messageContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            if !isConsecutive {
                MessageHeaderView(
                    message: message,
                    currentUserPubkey: currentUserPubkey,
                    showDebugInfo: showDebugInfo,
                    onAgentTap: onAgentTap,
                    onTimestampTap: onTimestampTap
                )
            }

            MessageContentView(message: message)

            if message.replyCount > 0, let onReplyTap {
                ReplyIndicatorView(
                    replyCount: message.replyCount,
                    authorPubkeys: message.replyAuthorPubkeys,
                    onTap: onReplyTap
                )
                .padding(.top, 4)
            }

            if !message.suggestions.isEmpty {
                suggestionsView
            }
        }
    }

    private var avatarColumnView: some View {
        VStack(spacing: 0) {
            if isConsecutive {
                threadContinuityLine
            } else {
                avatarView
            }
            if hasNextConsecutive {
                threadContinuityLineBelow
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
            if isAgent, let onAgentTap {
                Button(action: onAgentTap) {
                    avatar
                }
                .buttonStyle(.plain)
            } else {
                avatar
            }
        }
    }

    @ViewBuilder private var avatar: some View {
        if let ndk {
            NDKUIProfilePicture(ndk: ndk, pubkey: message.pubkey, size: 36)
        } else {
            Image(systemName: "person.circle.fill")
                .font(.system(size: 36))
                .foregroundStyle(isAgent ? .blue : .gray)
        }
    }

    private var suggestionsView: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(message.suggestions, id: \.self) { suggestion in
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

        Button {
            copyToClipboard(message.content)
        } label: {
            Label("Copy Content", systemImage: "doc.on.doc")
        }

        if let rawEventJSON = message.rawEventJSON {
            Button {
                copyToClipboard(rawEventJSON)
            } label: {
                Label("Copy Raw Event", systemImage: "doc.on.doc.fill")
            }
        }

        Button {
            copyToClipboard(message.id)
        } label: {
            Label("Copy ID", systemImage: "number")
        }

        if message.rawEventJSON != nil {
            Button {
                showRawEvent = true
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
