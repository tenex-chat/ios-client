//
// ReplyIndicatorView.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import SwiftUI
import TENEXShared

// MARK: - ReplyIndicatorView

/// Shows "X replies" with an avatar stack for reply authors.
/// Tapping this should navigate to a focused thread view.
public struct ReplyIndicatorView: View {
    // MARK: Lifecycle

    /// Initialize the reply indicator
    /// - Parameters:
    ///   - replyCount: Number of replies
    ///   - authorPubkeys: Pubkeys of reply authors (max 3 displayed)
    ///   - onTap: Action when tapped
    public init(
        replyCount: Int,
        authorPubkeys: [String],
        onTap: @escaping () -> Void
    ) {
        self.replyCount = replyCount
        self.authorPubkeys = authorPubkeys
        self.onTap = onTap
    }

    // MARK: Public

    public var body: some View {
        Button(action: self.onTap) {
            HStack(spacing: 8) {
                // Avatar stack (overlapping circles)
                self.avatarStack

                // Reply count text
                Text(self.replyText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }

    // MARK: Private

    private let replyCount: Int
    private let authorPubkeys: [String]
    private let onTap: () -> Void

    private var replyText: String {
        self.replyCount == 1 ? "1 reply" : "\(self.replyCount) replies"
    }

    private var avatarStack: some View {
        HStack(spacing: -8) {
            ForEach(Array(self.authorPubkeys.prefix(3).enumerated()), id: \.offset) { index, pubkey in
                Circle()
                    .fill(Color.deterministicColor(for: pubkey))
                    .frame(width: 20, height: 20)
                    .overlay {
                        Text(pubkey.prefix(1).uppercased())
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                    }
                    .overlay {
                        Circle()
                            .stroke(.background, lineWidth: 1.5)
                    }
                    .zIndex(Double(3 - index)) // Stack order: first pubkey on top
            }
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        ReplyIndicatorView(
            replyCount: 1,
            authorPubkeys: ["alice"]
        ) {}

        ReplyIndicatorView(
            replyCount: 3,
            authorPubkeys: ["alice", "bob", "charlie"]
        ) {}

        ReplyIndicatorView(
            replyCount: 15,
            authorPubkeys: ["alice", "bob", "charlie"]
        ) {}
    }
    .padding()
}
