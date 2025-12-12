//
// ProjectListView.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import SwiftUI
import TENEXCore

// MARK: - ProjectListView

/// View displaying a list of projects
public struct ProjectListView: View {
    // MARK: Lifecycle

    /// Initialize the project list view
    /// - Parameter viewModel: The view model for the project list
    public init(viewModel: ProjectListViewModel) {
        self.viewModel = viewModel
    }

    // MARK: Public

    public var body: some View {
        Group {
            if viewModel.isLoading, viewModel.projects.isEmpty {
                loadingView
            } else if viewModel.projects.isEmpty {
                emptyView
            } else {
                projectList
            }
        }
        .navigationTitle("Projects")
        .task {
            await viewModel.loadProjects()
        }
        .refreshable {
            await viewModel.refresh()
        }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") {
                // Error message will be cleared on next load
            }
        } message: {
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
            }
        }
    }

    // MARK: Private

    @State private var viewModel: ProjectListViewModel

    private var projectList: some View {
        List {
            ForEach(viewModel.projects) { project in
                ProjectRow(project: project)
            }
        }
        #if os(iOS)
        .listStyle(.insetGrouped)
        #else
        .listStyle(.inset)
        #endif
    }

    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
            Text("Loading projects...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var emptyView: some View {
        VStack(spacing: 20) {
            Image(systemName: "folder.fill")
                .font(.system(size: 60))
                .foregroundStyle(.blue)

            Text("No Projects")
                .font(.title)
                .fontWeight(.semibold)

            Text("You don't have any projects yet")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - ProjectRow

/// Row component displaying a single project
struct ProjectRow: View {
    // MARK: Lifecycle

    init(project: Project) {
        self.project = project
    }

    // MARK: Internal

    var body: some View {
        HStack(spacing: 12) {
            // Project avatar with HSL color
            RoundedRectangle(cornerRadius: 12)
                .fill(project.color)
                .frame(width: 56, height: 56)
                .overlay {
                    Text(project.title.prefix(1).uppercased())
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(.white)
                }

            // Project info
            VStack(alignment: .leading, spacing: 4) {
                Text(project.title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.primary)

                if let description = project.description {
                    Text(description)
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer()
        }
        .padding(.vertical, 8)
    }

    // MARK: Private

    private let project: Project
}
