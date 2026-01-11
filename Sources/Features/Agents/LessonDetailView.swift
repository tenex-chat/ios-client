//
// LessonDetailView.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import NDKSwiftCore
import NDKSwiftUI
import SwiftUI
import TENEXCore

// MARK: - LessonDetailView

/// Full-screen view for reading a lesson with all metadata
public struct LessonDetailView: View {
    // MARK: Lifecycle

    public init(lessonId: String, ndk: NDK) {
        self.lessonId = lessonId
        self.ndk = ndk
    }

    // MARK: Public

    public var body: some View {
        Group {
            if isLoading {
                loadingView
            } else if let lesson {
                lessonContent(lesson)
            } else {
                errorView
            }
        }
        .navigationTitle(lesson?.displayTitle ?? "Lesson")
        #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
            .task {
                await loadLesson()
            }
    }

    // MARK: Private

    private let lessonId: String
    private let ndk: NDK

    @State private var lesson: AgentLesson?
    @State private var isLoading = true

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Loading lesson...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Error View

    private var errorView: some View {
        ContentUnavailableView(
            "Lesson Not Found",
            systemImage: "book.closed",
            description: Text("This lesson could not be loaded.")
        )
    }

    // MARK: - Lesson Content

    private func lessonContent(_ lesson: AgentLesson) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerSection(lesson)
                Divider()
                mainContentSection(lesson)

                if lesson.hasLearningMetadata {
                    Divider()
                    learningMetadataSection(lesson)
                }
            }
            .padding()
        }
    }

    // MARK: - Header Section

    private func headerSection(_ lesson: AgentLesson) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                NDKUIProfilePicture(ndk: ndk, pubkey: lesson.pubkey, size: 40)

                VStack(alignment: .leading, spacing: 2) {
                    Text(ndk.profile(for: lesson.pubkey).displayName)
                        .font(.subheadline.weight(.medium))

                    Text(lesson.createdAt, style: .date)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if hasBadges(lesson) {
                badgesRow(lesson)
            }
        }
    }

    private func hasBadges(_ lesson: AgentLesson) -> Bool {
        lesson.category != nil || lesson.hasDetailedContent || !lesson.hashtags.isEmpty
    }

    @ViewBuilder
    private func badgesRow(_ lesson: AgentLesson) -> some View {
        HStack(spacing: 8) {
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
            .font(.caption.weight(.medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.blue.opacity(0.15))
            .foregroundStyle(.blue)
            .cornerRadius(6)
    }

    private var detailedBadge: some View {
        Text("Detailed")
            .font(.caption.weight(.medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.purple.opacity(0.15))
            .foregroundStyle(.purple)
            .cornerRadius(6)
    }

    private func hashtagBadge(_ tag: String) -> some View {
        Text("#\(tag)")
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    // MARK: - Main Content Section

    private func mainContentSection(_ lesson: AgentLesson) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Lesson", icon: "book.fill")

            Text(lesson.lesson)
                .font(.body)
                .textSelection(.enabled)
        }
    }

    // MARK: - Learning Metadata Section

    private func learningMetadataSection(_ lesson: AgentLesson) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Learning Process")
                .font(.headline)

            if let reasoning = lesson.reasoning {
                metadataCard(
                    title: "Reasoning",
                    icon: "brain.head.profile",
                    content: reasoning
                )
            }

            if let metacognition = lesson.metacognition {
                metadataCard(
                    title: "Metacognition",
                    icon: "lightbulb.fill",
                    content: metacognition
                )
            }

            if let reflection = lesson.reflection {
                metadataCard(
                    title: "Reflection",
                    icon: "arrow.triangle.2.circlepath",
                    content: reflection
                )
            }
        }
    }

    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }

    private func metadataCard(title: String, icon: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader(title, icon: icon)

            Text(content)
                .font(.subheadline)
                .foregroundStyle(.primary.opacity(0.9))
                .textSelection(.enabled)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.tertiarySystemBackground))
        .cornerRadius(12)
    }

    // MARK: - Data Loading

    private func loadLesson() async {
        isLoading = true
        defer { isLoading = false }

        let filter = AgentLesson.filter(forLessonId: lessonId)
        let subscription = ndk.subscribe(filter: filter)

        for await events in subscription.events.prefix(1) {
            for event in events {
                if let loadedLesson = AgentLesson.from(event: event) {
                    lesson = loadedLesson
                    return
                }
            }
        }
    }
}
