//
// ConversationRow.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import SwiftUI
import TENEXCore

/// A row displaying a conversation in the main Conversations tab
/// Inspired by the TUI's Recent tab layout
struct ConversationRow: View {
    // MARK: Internal

    let threadID: String
    let project: Project?
    let latestMessage: Message
    let conversationMetadata: ConversationMetadata?
    /// Depth in thread hierarchy (0 = root, 1+ = delegated child)
    var depth: Int = 0
    /// Whether this thread has child delegations
    var hasChildren: Bool = false
    /// Number of descendant threads
    var childCount: Int = 0

    // MARK: - Body

    var body: some View {
        HStack(spacing: 0) {
            hierarchyIndicator
            contentStack
        }
    }

    // MARK: Private

    /// Visual hierarchy indicator for nested delegations
    @ViewBuilder
    private var hierarchyIndicator: some View {
        if depth > 0 {
            HStack(spacing: 0) {
                // Indentation based on depth (16pt per level, max 3 levels visual)
                Color.clear
                    .frame(width: CGFloat(min(depth, 3)) * 16)

                // Tree connector line
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.3))
                        .frame(width: 1)
                    Circle()
                        .fill(Color.secondary.opacity(0.5))
                        .frame(width: 6, height: 6)
                    Rectangle()
                        .fill(Color.secondary.opacity(0.3))
                        .frame(width: 1)
                }
                .frame(width: 8)
            }
        }
    }

    private var contentStack: some View {
        VStack(alignment: .leading, spacing: 6) {
            titleRow
            summaryRow
            activityIndicatorRow
            tagsRow
            bottomRow
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var titleRow: some View {
        HStack(spacing: 8) {
            // Show delegation indicator for child threads
            if depth > 0 {
                Image(systemName: "arrow.turn.down.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(displayTitle)
                .font(.headline)
                .foregroundStyle(displayTitle == "Conversation" ? .secondary : .primary)
                .lineLimit(1)

            // Show child count badge if this thread has delegations
            if hasChildren, childCount > 0 {
                Text("\(childCount)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.15))
                    .clipShape(Capsule())
            }

            Spacer()

            if let statusLabel = conversationMetadata?.statusLabel {
                StatusLabelPill(label: statusLabel)
            }
        }
    }

    @ViewBuilder
    private var summaryRow: some View {
        if let summary = conversationMetadata?.summary, !summary.isEmpty {
            Text(summary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var activityIndicatorRow: some View {
        if let activity = conversationMetadata?.statusCurrentActivity, !activity.isEmpty {
            ActivityIndicator(activity: activity)
        }
    }

    @ViewBuilder
    private var tagsRow: some View {
        if let tags = conversationMetadata?.tags, !tags.isEmpty {
            FlowLayout(spacing: 4) {
                ForEach(tags, id: \.self) { tag in
                    TagPill(tag: tag)
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

            Text(latestMessage.createdAt, style: .relative)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    private var displayTitle: String {
        if let metadata = conversationMetadata, let title = metadata.title, !title.isEmpty {
            return title
        }
        return "Conversation"
    }
}
