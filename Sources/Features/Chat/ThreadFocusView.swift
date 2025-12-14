//
// ThreadFocusView.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import SwiftUI
import TENEXCore

// MARK: - ThreadFocusView

/// Focused view showing a message with its parent context and direct replies.
/// - Shows parent message (if any) with reduced opacity
/// - Shows focused message highlighted
/// - Shows direct replies below
public struct ThreadFocusView: View {
    // MARK: Lifecycle

    /// Initialize the thread focus view
    /// - Parameters:
    ///   - focusedMessage: The message being focused on
    ///   - parentMessage: Optional parent message for context
    ///   - replies: Direct replies to the focused message
    ///   - currentUserPubkey: The current user's pubkey
    ///   - onDismiss: Action when dismissing the view
    public init(
        focusedMessage: Message,
        parentMessage: Message?,
        replies: [Message],
        currentUserPubkey: String?,
        onDismiss: @escaping () -> Void
    ) {
        self.focusedMessage = focusedMessage
        self.parentMessage = parentMessage
        self.replies = replies
        self.currentUserPubkey = currentUserPubkey
        self.onDismiss = onDismiss
    }

    // MARK: Public

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Parent message context (if any)
                    if let parent = parentMessage {
                        parentSection(parent)
                    }

                    // Focused message (highlighted)
                    focusedSection

                    // Replies
                    if !replies.isEmpty {
                        repliesSection
                    }
                }
            }
            .navigationTitle("Thread")
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close", action: onDismiss)
                    }
                }
        }
    }

    // MARK: Private

    private let focusedMessage: Message
    private let parentMessage: Message?
    private let replies: [Message]
    private let currentUserPubkey: String?
    private let onDismiss: () -> Void

    private var focusedSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            MessageRow(message: focusedMessage, currentUserPubkey: currentUserPubkey)
                .padding(.horizontal, 16)
                .background(Color.accentColor.opacity(0.05))

            if !replies.isEmpty {
                Divider()
                    .padding(.horizontal, 16)
            }
        }
    }

    private var repliesSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("\(replies.count) \(replies.count == 1 ? "reply" : "replies")")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
                .padding(.top, 8)

            ForEach(replies, id: \.id) { reply in
                MessageRow(message: reply, currentUserPubkey: currentUserPubkey)
                    .padding(.horizontal, 16)

                if reply.id != replies.last?.id {
                    Divider()
                        .padding(.horizontal, 16)
                }
            }
        }
    }

    private func parentSection(_ parent: Message) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("In reply to")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
                .padding(.top, 8)

            MessageRow(message: parent, currentUserPubkey: currentUserPubkey)
                .padding(.horizontal, 16)
                .opacity(0.6)

            Divider()
                .padding(.horizontal, 16)
        }
    }
}

// MARK: - Preview

#Preview {
    ThreadFocusView(
        focusedMessage: .previewFocused,
        parentMessage: .previewParent,
        replies: [.previewReply1, .previewReply2],
        currentUserPubkey: "user1"
    ) {}
}

// MARK: - Preview Helpers

private extension Message {
    static let previewParent = Message(
        id: "parent",
        pubkey: "user2",
        threadID: "thread1",
        content: "Parent message.",
        createdAt: Date().addingTimeInterval(-3600),
        replyTo: nil,
        kind: 1111
    )
    static let previewFocused = Message(
        id: "focused",
        pubkey: "user1",
        threadID: "thread1",
        content: "Focused message with **markdown**.",
        createdAt: Date(),
        replyTo: "parent",
        kind: 1111
    )
    static let previewReply1 = Message(
        id: "reply1",
        pubkey: "user3",
        threadID: "thread1",
        content: "First reply.",
        createdAt: Date().addingTimeInterval(60),
        replyTo: "focused",
        kind: 1111
    )
    static let previewReply2 = Message(
        id: "reply2",
        pubkey: "user4",
        threadID: "thread1",
        content: "Second reply.",
        createdAt: Date().addingTimeInterval(120),
        replyTo: "focused",
        kind: 1111
    )
}
