//
// ReplyIndicatorView.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import NDKSwiftCore
import NDKSwiftUI
import SwiftUI
import TENEXShared

// MARK: - ReplyIndicatorView

/// Shows "X replies" with an avatar stack for reply authors.
/// Tapping this should navigate to a focused thread view.
public struct ReplyIndicatorView: View {
    // MARK: Lifecycle

    /// Initialize the reply indicator
    /// - Parameters:
    ///   - ndk: NDK instance for profile pictures
    ///   - replyCount: Number of replies
    ///   - authorPubkeys: Pubkeys of reply authors (max 3 displayed)
    ///   - onTap: Action when tapped
    public init(
        ndk: NDK,
        replyCount: Int,
        authorPubkeys: [String],
        onTap: @escaping () -> Void
    ) {
        self.ndk = ndk
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

    private let ndk: NDK
    private let replyCount: Int
    private let authorPubkeys: [String]
    private let onTap: () -> Void

    private var replyText: String {
        self.replyCount == 1 ? "1 reply" : "\(self.replyCount) replies"
    }

    private var avatarStack: some View {
        HStack(spacing: -8) {
            ForEach(Array(self.authorPubkeys.prefix(3).enumerated()), id: \.offset) { index, pubkey in
                NDKUIProfilePicture(ndk: self.ndk, pubkey: pubkey, size: 20)
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
    let ndk = NDK(relayURLs: ["wss://relay.damus.io"])
    VStack(spacing: 20) {
        ReplyIndicatorView(
            ndk: ndk,
            replyCount: 1,
            authorPubkeys: ["alice"]
        ) {}

        ReplyIndicatorView(
            ndk: ndk,
            replyCount: 3,
            authorPubkeys: ["alice", "bob", "charlie"]
        ) {}

        ReplyIndicatorView(
            ndk: ndk,
            replyCount: 15,
            authorPubkeys: ["alice", "bob", "charlie"]
        ) {}
    }
    .padding()
}
