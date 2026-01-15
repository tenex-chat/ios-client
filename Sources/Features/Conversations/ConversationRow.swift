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
        if hasActivity {
            Rectangle()
                .fill(Color.green)
                .frame(width: 3)
                .shadow(color: .green.opacity(0.6), radius: 4, x: 0, y: 0)
        }
    }

    private var contentStack: some View {
        VStack(alignment: .leading, spacing: 6) {
            titleRow
            activityIndicatorRow
            messagePreview
            bottomRow
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var titleRow: some View {
        HStack(spacing: 8) {
            Text(displayTitle)
                .font(.headline)
                .foregroundStyle(displayTitle == "Conversation" ? .secondary : .primary)
                .lineLimit(1)

            Spacer()

            if let statusLabel = conversationMetadata?.statusLabel {
                StatusLabelPill(label: statusLabel)
            }
        }
    }

    @ViewBuilder
    private var activityIndicatorRow: some View {
        if let activity = conversationMetadata?.statusCurrentActivity, !activity.isEmpty {
            ActivityIndicator(activity: activity)
        }
    }

    private var messagePreview: some View {
        Text(latestMessage.content.replacingOccurrences(of: "\n", with: " "))
            .font(.subheadline)
            .foregroundStyle(.secondary)
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

    private var hasActivity: Bool {
        conversationMetadata?.hasActivity ?? false
    }
}
