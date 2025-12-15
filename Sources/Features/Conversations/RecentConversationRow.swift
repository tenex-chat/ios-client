//
// RecentConversationRow.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import SwiftUI
import TENEXCore

struct RecentConversationRow: View {
    // MARK: Internal

    let threadID: String
    let thread: TENEXCore.Thread?
    let project: Project?
    let latestMessage: Message
    let conversationMetadata: ConversationMetadata?

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                if let project {
                    Circle()
                        .fill(project.color)
                        .frame(width: 8, height: 8)

                    Text(project.title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(self.latestMessage.createdAt, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Text(self.displayTitle)
                .font(.headline)
                .foregroundStyle(self.displayTitle == "Thread" ? .secondary : .primary)

            Text(self.latestMessage.content)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    // MARK: Private

    private var displayTitle: String {
        if let metadata = conversationMetadata, let title = metadata.title, !title.isEmpty {
            return title
        }
        if let thread, !thread.title.isEmpty {
            return thread.title
        }
        return "Thread"
    }
}
