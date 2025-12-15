//
// InboxRow.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import SwiftUI
import TENEXCore

struct InboxRow: View {
    let message: Message
    let isUnread: Bool
    let agentName: String?

    // MARK: - Body

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Unread indicator
            Circle()
                .fill(self.isUnread ? Color.blue : Color.clear)
                .frame(width: 8, height: 8)
                .padding(.top, 6)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    // Agent name from project status or truncated pubkey
                    Text(self.agentName ?? String(self.message.pubkey.prefix(8)))
                        .font(.headline)

                    Spacer()

                    Text(self.message.createdAt, style: .relative)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Message content preview
                Text(self.message.content)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)

                // Show "Needs Response" badge if this is an escalation (ask tag)
                if self.message.hasAskTag {
                    Text("Needs Response")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.2))
                        .foregroundStyle(.orange)
                        .cornerRadius(4)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
