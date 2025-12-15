//
// RecentConversationRow.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import SwiftUI
import TENEXCore

struct RecentConversationRow: View {
    let threadID: String
    let thread: TENEXCore.Thread?
    let project: Project?
    let latestMessage: Message

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header row with project badge and timestamp
            HStack(spacing: 8) {
                if let project {
                    // Project badge
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

            // Thread title
            if let thread {
                Text(thread.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
            } else {
                Text("Thread")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }

            // Latest message preview
            Text(self.latestMessage.content)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(.vertical, 4)
    }
}
