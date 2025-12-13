//
// NavigationShell.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import OSLog
import SwiftUI
import TENEXCore

// MARK: - NavigationShell

/// Main navigation container for the app
/// Uses NavigationStack for iPhone, prepared for NavigationSplitView on iPad (future milestone)
public struct NavigationShell: View {
    // MARK: Lifecycle

    public init() {}

    // MARK: Public

    public var body: some View {
        NavigationStack(path: $router.path) {
            rootView
                .navigationDestination(for: AppRoute.self) { route in
                    destinationView(for: route)
                }
                .toolbar {
                    #if os(iOS)
                        ToolbarItem(placement: .topBarTrailing) {
                            HStack(spacing: 16) {
                                settingsButton
                                signOutButton
                            }
                        }
                    #else
                        ToolbarItem(placement: .primaryAction) {
                            HStack(spacing: 16) {
                                settingsButton
                                signOutButton
                            }
                        }
                    #endif
                }
        }
        .onOpenURL { url in
            handleDeepLink(url)
        }
    }

    // MARK: Private

    @Environment(AuthManager.self) private var authManager
    @Environment(\.ndk) private var ndk
    @State private var router = NavigationRouter()
    @State private var showingSignOutConfirmation = false
    @State private var isSigningOut = false
    @State private var projects: [Project] = []

    // MARK: - Root View

    private var rootView: some View {
        Group {
            if let ndk, let userPubkey = authManager.currentUser?.pubkey {
                ProjectListView(
                    viewModel: ProjectListViewModel(
                        ndk: ndk,
                        userPubkey: userPubkey
                    )
                )
            } else {
                Text("Loading...")
            }
        }
        .task {
            await loadProjects()
        }
    }

    // MARK: - Settings

    private var settingsButton: some View {
        NavigationLink(value: AppRoute.settings) {
            Label("Settings", systemImage: "gearshape")
        }
    }

    // MARK: - Sign Out

    private var signOutButton: some View {
        Button {
            showingSignOutConfirmation = true
        } label: {
            if isSigningOut {
                ProgressView()
                    .progressViewStyle(.circular)
            } else {
                Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
            }
        }
        .disabled(isSigningOut)
        .confirmationDialog(
            "Are you sure you want to sign out?",
            isPresented: $showingSignOutConfirmation,
            titleVisibility: .visible
        ) {
            Button("Sign Out", role: .destructive) {
                Task {
                    await performSignOut()
                }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: - Destination Views

    @ViewBuilder
    private func destinationView(for route: AppRoute) -> some View {
        switch route {
        case .projectList:
            if let ndk, let userPubkey = authManager.currentUser?.pubkey {
                ProjectListView(
                    viewModel: ProjectListViewModel(
                        ndk: ndk,
                        userPubkey: userPubkey
                    )
                )
            } else {
                Text("Loading...")
            }

        case let .project(id):
            if let ndk, let project = projects.first(where: { $0.id == id }) {
                ProjectDetailView(project: project, ndk: ndk)
            } else {
                ProjectDetailPlaceholder(projectID: id)
            }

        case let .threadList(projectID):
            ThreadListPlaceholder(projectID: projectID)

        case let .thread(projectID, threadID):
            ThreadDetailPlaceholder(projectID: projectID, threadID: threadID)

        case .settings:
            if let ndk {
                SettingsView(ndk: ndk)
            } else {
                Text("Loading...")
            }
        }
    }

    // MARK: - Deep Link Handling

    private func handleDeepLink(_ url: URL) {
        do {
            try router.handleDeepLink(url)
        } catch {
            Logger().error("Failed to handle deep link: \(error.localizedDescription)")
        }
    }

    // MARK: - Project Loading

    private func loadProjects() async {
        guard let ndk, let userPubkey = authManager.currentUser?.pubkey else {
            return
        }

        do {
            let filter = Project.filter(for: userPubkey)
            let subscription = ndk.subscribeToEvents(filters: [filter])

            var projectsByID: [String: Project] = [:]
            var projectOrder: [String] = []

            for try await event in subscription {
                if let project = Project.from(event: event) {
                    // Update projects map (handles replaceable events)
                    if projectsByID[project.id] == nil {
                        projectOrder.append(project.id)
                    }
                    projectsByID[project.id] = project

                    // Update UI immediately as events arrive (maintaining order)
                    projects = projectOrder.compactMap { projectsByID[$0] }
                }
            }

            // Subscription finished (after EOSE)
        } catch {
            Logger().error("Failed to load projects: \(error.localizedDescription)")
        }
    }

    private func performSignOut() async {
        isSigningOut = true

        defer {
            isSigningOut = false
        }

        do {
            try await authManager.signOut()
        } catch {
            Logger().error("Failed to sign out: \(error.localizedDescription)")
        }
    }
}

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
