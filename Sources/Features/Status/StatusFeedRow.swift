//
// StatusFeedRow.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import SwiftUI
import TENEXCore

/// A row displaying conversation status metadata in the Status feed
struct StatusFeedRow: View {
    // MARK: Internal

    let metadata: ConversationMetadata
    let project: Project?

    // MARK: - Body

    var body: some View {
        HStack(spacing: 0) {
            activityBar
            contentStack
        }
    }

    // MARK: Private

    @ViewBuilder
    private var activityBar: some View {
        if metadata.hasActivity {
            Rectangle()
                .fill(Color.green)
                .frame(width: 3)
                .shadow(color: .green.opacity(0.6), radius: 4, x: 0, y: 0)
        }
    }

    private var contentStack: some View {
        VStack(alignment: .leading, spacing: 6) {
            titleRow
            summaryText
            activityRow
            tagsRow
            bottomRow
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var titleRow: some View {
        HStack(spacing: 8) {
            Text(displayTitle)
                .font(.headline)
                .foregroundStyle(displayTitle == "Conversation" ? .secondary : .primary)
                .lineLimit(1)

            Spacer()

            if let statusLabel = metadata.statusLabel {
                StatusLabelPill(label: statusLabel)
            }
        }
    }

    @ViewBuilder
    private var summaryText: some View {
        if let summary = metadata.summary, !summary.isEmpty {
            Text(summary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
    }

    @ViewBuilder
    private var activityRow: some View {
        if let activity = metadata.statusCurrentActivity, !activity.isEmpty {
            ActivityIndicator(activity: activity)
        }
    }

    @ViewBuilder
    private var tagsRow: some View {
        if !metadata.tags.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(metadata.tags, id: \.self) { tag in
                        TagPill(tag: tag)
                    }
                }
            }
        }
    }

    private var bottomRow: some View {
        HStack(spacing: 8) {
            if let project {
                ProjectIndicator(title: project.title, color: project.color)
            }

            Spacer()

            Text(metadata.createdAt, style: .relative)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    private var displayTitle: String {
        if let title = metadata.title, !title.isEmpty {
            return title
        }
        return "Conversation"
    }
}

// MARK: - Preview

#if DEBUG
    #Preview {
        List {
            StatusFeedRow(
                metadata: .preview(
                    threadID: "abc123",
                    title: "Implementing dark mode",
                    summary: "Working on the new dark mode feature for the app",
                    statusLabel: "In Progress",
                    statusCurrentActivity: "Writing integration tests...",
                    tags: ["feature", "ui"]
                ),
                project: nil
            )
            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))

            StatusFeedRow(
                metadata: .preview(
                    threadID: "def456",
                    title: "Bug fix: Login issue",
                    statusLabel: "Completed"
                ),
                project: nil
            )
            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
        }
        .listStyle(.plain)
    }
#endif

// MARK: - Preview Helper

#if DEBUG
    extension ConversationMetadata {
        static func preview(
            threadID: String = "preview",
            pubkey: String = "pubkey",
            title: String? = nil,
            summary: String? = nil,
            statusLabel: String? = nil,
            statusCurrentActivity: String? = nil,
            tags: [String] = [],
            projectCoordinate: String? = nil,
            createdAt: Date = Date()
        ) -> ConversationMetadata {
            ConversationMetadata(
                threadID: threadID,
                pubkey: pubkey,
                title: title,
                summary: summary,
                statusLabel: statusLabel,
                statusCurrentActivity: statusCurrentActivity,
                tags: tags,
                projectCoordinate: projectCoordinate,
                createdAt: createdAt,
                event: nil
            )
        }
    }
#endif
