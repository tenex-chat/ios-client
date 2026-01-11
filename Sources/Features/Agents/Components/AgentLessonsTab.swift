//
// AgentLessonsTab.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import NDKSwiftCore
import SwiftUI
import TENEXCore

// MARK: - AgentLessonsTab

/// Tab content displaying lessons learned by an agent
public struct AgentLessonsTab: View {
    // MARK: Lifecycle

    public init(agentPubkey: String, ndk: NDK) {
        self.agentPubkey = agentPubkey
        self.ndk = ndk
    }

    // MARK: Public

    public var body: some View {
        Group {
            if isLoading {
                loadingView
            } else if lessons.isEmpty {
                emptyState
            } else {
                lessonList
            }
        }
        .task {
            await loadLessons()
        }
    }

    // MARK: Private

    private let agentPubkey: String
    private let ndk: NDK

    @State private var lessons: [AgentLesson] = []
    @State private var isLoading = true

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Loading lessons...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "book.closed")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("No Lessons Yet")
                .font(.headline)

            Text("This agent hasn't learned any lessons yet.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Lesson List

    private var lessonList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(lessons) { lesson in
                    NavigationLink(value: AppRoute.lesson(lesson.id)) {
                        LessonCard(lesson: lesson)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
    }

    // MARK: - Data Loading

    private func loadLessons() async {
        isLoading = true
        defer { isLoading = false }

        let filter = AgentLesson.filter(forAgent: agentPubkey)
        let subscription = ndk.subscribe(filter: filter)

        var lessonsByID: [String: AgentLesson] = [:]

        // Collect lessons with a timeout
        let timeout = Task {
            try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
        }

        for await events in subscription.events {
            if Task.isCancelled || timeout.isCancelled {
                break
            }

            for event in events {
                if let lesson = AgentLesson.from(event: event) {
                    lessonsByID[lesson.id] = lesson
                }
            }

            // Update the lessons list sorted by date
            lessons = lessonsByID.values
                .sorted { $0.createdAt > $1.createdAt }

            // Stop after collecting enough
            if lessonsByID.count >= 50 {
                break
            }
        }

        timeout.cancel()
    }
}
