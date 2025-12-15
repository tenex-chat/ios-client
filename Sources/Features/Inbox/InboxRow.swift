//
// InboxRow.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import NDKSwiftUI
import SwiftUI
import TENEXCore

struct InboxRow: View {
    // MARK: Internal

    let message: Message
    let isUnread: Bool
    let agentName: String?

    // MARK: - Body

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            self.avatarView
            self.messageContent
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    // MARK: Private

    @Environment(\.ndk) private var ndk

    private var avatarView: some View {
        Group {
            if let ndk {
                NDKUIProfilePicture(ndk: ndk, pubkey: self.message.pubkey, size: 40)
            } else {
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 40, height: 40)
            }
        }
    }

    private var messageContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            self.headerRow
            self.messagePreview
            if self.message.hasAskTag {
                self.needsResponseBadge
            }
        }
    }

    private var headerRow: some View {
        HStack {
            Text(self.agentName ?? String(self.message.pubkey.prefix(8)))
                .font(.headline)

            if self.isUnread {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 8, height: 8)
            }

            Spacer()

            Text(self.message.createdAt, style: .relative)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var messagePreview: some View {
        Text(self.message.content)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .lineLimit(3)
    }

    private var needsResponseBadge: some View {
        Text("Needs Response")
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.orange.opacity(0.2))
            .foregroundStyle(.orange)
            .cornerRadius(4)
    }
}
