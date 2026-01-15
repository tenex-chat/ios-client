//
// LessonCard.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import NDKSwiftCore
import SwiftUI
import TENEXCore

// MARK: - LessonCard

/// Card component for displaying a lesson in a list
public struct LessonCard: View {
    // MARK: Lifecycle

    public init(lesson: AgentLesson, compact: Bool = false) {
        self.lesson = lesson
        self.compact = compact
    }

    // MARK: Public

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerSection
            Divider()
            contentSection
        }
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.separator), lineWidth: 0.5)
        )
    }

    // MARK: Private

    private let lesson: AgentLesson
    private let compact: Bool

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                Text(lesson.displayTitle)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)

                Spacer()

                Text(lesson.createdAt, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if hasBadgesOrHashtags {
                badgesRow
            }
        }
        .padding()
    }

    private var hasBadgesOrHashtags: Bool {
        lesson.category != nil || lesson.hasDetailedContent || !lesson.hashtags.isEmpty
    }

    @ViewBuilder
    private var badgesRow: some View {
        FlowLayout(spacing: 6) {
            if let category = lesson.category {
                categoryBadge(category)
            }

            if lesson.hasDetailedContent {
                detailedBadge
            }

            ForEach(lesson.hashtags.prefix(5), id: \.self) { tag in
                hashtagBadge(tag)
            }
        }
    }

    private func categoryBadge(_ category: String) -> some View {
        Text(category)
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.blue.opacity(0.15))
            .foregroundStyle(.blue)
            .cornerRadius(4)
    }

    private var detailedBadge: some View {
        Text("Detailed")
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.purple.opacity(0.15))
            .foregroundStyle(.purple)
            .cornerRadius(4)
    }

    private func hashtagBadge(_ tag: String) -> some View {
        Text("#\(tag)")
            .font(.caption2)
            .foregroundStyle(.secondary)
    }

    // MARK: - Content Section

    private var contentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            lessonContentPreview

            if !compact && lesson.hasLearningMetadata {
                metadataPreview
            }
        }
        .padding()
    }

    private var lessonContentPreview: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Lesson")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)

                if lesson.hasDetailedContent {
                    Text("(summary)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            Text(lesson.lesson)
                .font(.subheadline)
                .lineLimit(compact ? 2 : 3)
                .foregroundStyle(.primary)
        }
    }

    @ViewBuilder
    private var metadataPreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let reasoning = lesson.reasoning {
                metadataField(title: "Reasoning", content: reasoning)
            }

            if let metacognition = lesson.metacognition {
                metadataField(title: "Metacognition", content: metacognition)
            }

            if let reflection = lesson.reflection {
                metadataField(title: "Reflection", content: reflection)
            }
        }
    }

    private func metadataField(title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

            Text(content)
                .font(.caption)
                .lineLimit(2)
                .foregroundStyle(.primary.opacity(0.8))
        }
    }
}

// MARK: - Preview

// swiftlint:disable closure_body_length
#Preview {
    ScrollView {
        VStack(spacing: 16) {
            LessonCard(
                lesson: AgentLesson(
                    id: "1",
                    pubkey: "test",
                    createdAt: Date(),
                    agentDefinitionId: nil,
                    title: "Understanding Context Windows",
                    lesson: "When working with large codebases, it's important to be strategic.",
                    metacognition: "I notice I work better with concrete examples.",
                    reasoning: "By analyzing patterns across similar tasks...",
                    reflection: "This approach has reduced errors significantly.",
                    detailed: "true",
                    category: "Performance",
                    hashtags: ["learning", "context", "optimization"],
                    event: NDKEvent(
                        id: "preview-1",
                        pubkey: "test",
                        createdAt: Int64(Date().timeIntervalSince1970),
                        kind: 4129,
                        tags: [],
                        content: "When working with large codebases, it's important to be strategic.",
                        sig: "preview-sig"
                    )
                )
            )

            LessonCard(
                lesson: AgentLesson(
                    id: "2",
                    pubkey: "test",
                    createdAt: Date().addingTimeInterval(-3600),
                    agentDefinitionId: nil,
                    title: nil,
                    lesson: "Always verify assumptions before making changes to critical systems.",
                    metacognition: nil,
                    reasoning: nil,
                    reflection: nil,
                    detailed: nil,
                    category: nil,
                    hashtags: [],
                    event: NDKEvent(
                        id: "preview-2",
                        pubkey: "test",
                        createdAt: Int64(Date().timeIntervalSince1970 - 3600),
                        kind: 4129,
                        tags: [],
                        content: "Always verify assumptions before making changes to critical systems.",
                        sig: "preview-sig"
                    )
                ),
                compact: true
            )
        }
        .padding()
    }
}
// swiftlint:enable closure_body_length
