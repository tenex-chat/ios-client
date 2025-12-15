//
// MessageBubble.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import SwiftUI
import TENEXCore

// MARK: - MessageBubble

/// Individual message bubble in the conversation
public struct MessageBubble: View {
    // MARK: Lifecycle

    public init(message: Message, accentColor: Color, userPubkey: String, onReplay: @escaping () -> Void) {
        self.message = message
        self.accentColor = accentColor
        self.userPubkey = userPubkey
        self.onReplay = onReplay
    }

    // MARK: Public

    public var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if !self.isUser {
                Spacer(minLength: 40)
            }

            self.messageContent

            if self.isUser {
                Spacer(minLength: 40)
            }
        }
    }

    // MARK: Internal

    let message: Message
    let accentColor: Color
    let userPubkey: String
    let onReplay: () -> Void

    // MARK: Private

    /// Check if message is from the current user
    private var isUser: Bool {
        self.message.pubkey == self.userPubkey
    }

    private var displayName: String {
        // Use message profile or pubkey
        self.message.profile?.displayName ?? self.message.pubkey.prefix(8).description
    }

    private var messageContent: some View {
        VStack(alignment: self.isUser ? .trailing : .leading, spacing: 6) {
            Text(self.displayName)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))

            self.messageWithReplay

            Text(self.formatTimestamp(self.message.createdAt))
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.5))
        }
    }

    private var messageWithReplay: some View {
        HStack(alignment: .bottom, spacing: 8) {
            Text(self.message.content)
                .font(.body)
                .foregroundStyle(.white)
                .padding(12)
                .background(self.isUser ? self.accentColor.opacity(0.8) : Color.white.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 16))

            if !self.isUser {
                self.replayButton
            }
        }
    }

    private var replayButton: some View {
        Button(action: self.onReplay) {
            Image(systemName: "speaker.wave.2.fill")
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.6))
                .padding(8)
                .background(Color.white.opacity(0.1))
                .clipShape(Circle())
        }
    }

    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
