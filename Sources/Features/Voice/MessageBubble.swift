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

    public init(message: CallMessage, accentColor: Color, onReplay: @escaping () -> Void) {
        self.message = message
        self.accentColor = accentColor
        self.onReplay = onReplay
    }

    // MARK: Public

    public var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if !isUser {
                Spacer(minLength: 40)
            }

            messageContent

            if isUser {
                Spacer(minLength: 40)
            }
        }
    }

    // MARK: Internal

    let message: CallMessage
    let accentColor: Color
    let onReplay: () -> Void

    // MARK: Private

    private var isUser: Bool {
        if case .user = message.sender {
            return true
        }
        return false
    }

    private var messageContent: some View {
        VStack(alignment: isUser ? .trailing : .leading, spacing: 6) {
            Text(message.sender.displayName)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))

            messageWithReplay

            Text(formatTimestamp(message.timestamp))
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.5))
        }
    }

    private var messageWithReplay: some View {
        HStack(alignment: .bottom, spacing: 8) {
            Text(message.content)
                .font(.body)
                .foregroundStyle(.white)
                .padding(12)
                .background(isUser ? accentColor.opacity(0.8) : Color.white.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 16))

            if !isUser {
                replayButton
            }
        }
    }

    private var replayButton: some View {
        Button(action: onReplay) {
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
