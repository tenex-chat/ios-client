//
// ReplyContextBanner.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import SwiftUI
import TENEXCore

// MARK: - ReplyContextBanner

/// Banner showing the message being replied to
public struct ReplyContextBanner: View {
    // MARK: Lifecycle

    public init(message: Message, onCancel: @escaping () -> Void) {
        self.message = message
        self.onCancel = onCancel
    }

    // MARK: Public

    public var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "arrowshape.turn.up.left")
                .font(.system(size: 14))
                .foregroundStyle(.blue)

            VStack(alignment: .leading, spacing: 2) {
                Text("Replying to")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(message.content)
                    .font(.caption)
                    .lineLimit(1)
                    .foregroundStyle(.primary)
            }

            Spacer()

            Button(action: onCancel) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.blue.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: Private

    private let message: Message
    private let onCancel: () -> Void
}
