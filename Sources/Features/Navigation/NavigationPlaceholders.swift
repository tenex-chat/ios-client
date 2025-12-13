//
// NavigationPlaceholders.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import SwiftUI

// MARK: - ProjectListPlaceholder

// These will be replaced with actual implementations in future milestones

struct ProjectListPlaceholder: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "folder.fill")
                .font(.system(size: 60))
                .foregroundStyle(.blue)

            Text("Project List")
                .font(.title)
                .fontWeight(.semibold)

            Text("Coming in Milestone 1.2")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .navigationTitle("Projects")
    }
}

// MARK: - ProjectDetailPlaceholder

struct ProjectDetailPlaceholder: View {
    let projectID: String

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "folder.badge.gearshape")
                .font(.system(size: 60))
                .foregroundStyle(.blue)

            Text("Project Detail")
                .font(.title)
                .fontWeight(.semibold)

            Text("Project ID: \(projectID)")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("Coming in Milestone 1.2")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .navigationTitle("Project")
    }
}

// MARK: - ThreadListPlaceholder

struct ThreadListPlaceholder: View {
    let projectID: String

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .font(.system(size: 60))
                .foregroundStyle(.blue)

            Text("Thread List")
                .font(.title)
                .fontWeight(.semibold)

            Text("Project ID: \(projectID)")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("Coming in Milestone 2")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .navigationTitle("Threads")
    }
}

// MARK: - ThreadDetailPlaceholder

struct ThreadDetailPlaceholder: View {
    let projectID: String
    let threadID: String

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "message.fill")
                .font(.system(size: 60))
                .foregroundStyle(.blue)

            Text("Thread Detail")
                .font(.title)
                .fontWeight(.semibold)

            Text("Project: \(projectID)")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("Thread: \(threadID)")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("Coming in Milestone 3")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .navigationTitle("Chat")
    }
}
