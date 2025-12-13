//
// AdaptiveNavigationShell.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import OSLog
import SwiftUI
import TENEXCore

// MARK: - AdaptiveNavigationShell

/// A navigation shell that adapts to the device's size class and OS.
/// Uses NavigationStack for compact layouts (iPhone) and NavigationSplitView for expanded layouts (iPad/macOS).
public struct AdaptiveNavigationShell: View {
    // MARK: Lifecycle

    public init() {}

    // MARK: Public

    public var body: some View {
        #if os(macOS)
            ExpandedNavigationShell()
        #else
            if horizontalSizeClass == .regular {
                ExpandedNavigationShell()
            } else {
                CompactNavigationShell()
            }
        #endif
    }

    // MARK: Private

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
}

// MARK: - CompactNavigationShell

/// The navigation shell for compact layouts (iPhone), using NavigationStack.
struct CompactNavigationShell: View {
    // MARK: Internal

    var body: some View {
        NavigationStack(path: $router.path) {
            rootView
                .navigationDestination(for: AppRoute.self) { route in
                    destinationView(for: route)
                }
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        HStack(spacing: 16) {
                            settingsButton
                            signOutButton
                        }
                    }
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
            if let project = projects.first(where: { $0.id == id }) {
                ProjectDetailView(project: project)
            } else {
                ProjectDetailPlaceholder(projectID: id)
            }

        case let .threadList(projectID):
            ThreadListPlaceholder(projectID: projectID)

        case let .thread(projectID, threadID):
            if let project = projects.first(where: { $0.id == projectID }),
               let userPubkey = authManager.currentUser?.pubkey {
                ChatLoaderView(threadID: threadID, project: project, currentUserPubkey: userPubkey)
            } else {
                ThreadDetailPlaceholder(projectID: projectID, threadID: threadID)
            }

        case let .agents(projectID):
            if let ndk {
                AgentsTabView(viewModel: AgentsTabViewModel(ndk: ndk, projectID: projectID))
            } else {
                Text("Loading...")
            }

        case .settings:
            SettingsView()
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
                    if projectsByID[project.id] == nil {
                        projectOrder.append(project.id)
                    }
                    projectsByID[project.id] = project
                    projects = projectOrder.compactMap { projectsByID[$0] }
                }
            }
        } catch {
            Logger().error("Failed to load projects: \(error.localizedDescription)")
        }
    }

    private func performSignOut() async {
        isSigningOut = true
        defer { isSigningOut = false }
        do {
            try await authManager.signOut()
        } catch {
            Logger().error("Failed to sign out: \(error.localizedDescription)")
        }
    }
}

// MARK: - ExpandedNavigationShell

/// The navigation shell for expanded layouts (iPad/macOS), using NavigationSplitView.
struct ExpandedNavigationShell: View {
    @Environment(AuthManager.self) private var authManager
    @Environment(\.ndk) private var ndk

    @State private var selectedProjectID: String?
    @State private var selectedThreadID: String?
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var projects: [Project] = []

    @State private var showingSignOutConfirmation = false
    @State private var isSigningOut = false

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            // Sidebar: Project List
            if let ndk, let userPubkey = authManager.currentUser?.pubkey {
                 // Using a modified ProjectListView that supports selection
                 ProjectListSidebar(
                     viewModel: ProjectListViewModel(ndk: ndk, userPubkey: userPubkey),
                     selectedProjectID: $selectedProjectID
                 )
            } else {
                Text("Loading...")
            }
        } content: {
            // Content: Thread List (Project Detail)
            if let selectedProjectID {
                if let project = projects.first(where: { $0.id == selectedProjectID }) {
                     // Pass selectedThreadID binding to ProjectDetailView
                     ProjectDetailView(project: project, selectedThreadID: $selectedThreadID)
                        .id(selectedProjectID) // Reset state when project changes
                } else {
                    Text("Project not found")
                }
            } else {
                Text("Select a Project")
                    .foregroundStyle(.secondary)
            }
        } detail: {
            // Detail: Chat / Thread Detail
            if let selectedProjectID, let selectedThreadID {
                if let project = projects.first(where: { $0.id == selectedProjectID }),
                   let userPubkey = authManager.currentUser?.pubkey {
                    ChatLoaderView(threadID: selectedThreadID, project: project, currentUserPubkey: userPubkey)
                } else {
                    ThreadDetailPlaceholder(projectID: selectedProjectID, threadID: selectedThreadID)
                }
            } else {
                Text("Select a Thread")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationSplitViewStyle(.balanced)
        #if os(macOS)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                HStack {
                     settingsButton
                     signOutButton
                }
            }
        }
        #endif
        .task {
            await loadProjects()
        }
    }

    // MARK: - Settings

    private var settingsButton: some View {
        Button(action: {
             // Handle settings presentation
        }) {
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

    private func loadProjects() async {
        guard let ndk, let userPubkey = authManager.currentUser?.pubkey else { return }
        do {
            let filter = Project.filter(for: userPubkey)
            let subscription = ndk.subscribeToEvents(filters: [filter])
            var projectsByID: [String: Project] = [:]
            var projectOrder: [String] = []
            for try await event in subscription {
                if let project = Project.from(event: event) {
                    if projectsByID[project.id] == nil {
                         projectOrder.append(project.id)
                    }
                    projectsByID[project.id] = project
                    projects = projectOrder.compactMap { projectsByID[$0] }
                }
            }
        } catch {
            Logger().error("Failed to load projects: \(error.localizedDescription)")
        }
    }

    private func performSignOut() async {
        isSigningOut = true
        defer { isSigningOut = false }
        do {
            try await authManager.signOut()
        } catch {
            Logger().error("Failed to sign out: \(error.localizedDescription)")
        }
    }
}

// We need a Sidebar version of ProjectListView
struct ProjectListSidebar: View {
    @State var viewModel: ProjectListViewModel
    @Binding var selectedProjectID: String?

    var body: some View {
        List(selection: $selectedProjectID) {
            ForEach(viewModel.projects) { project in
                ProjectRow(project: project)
                    .tag(project.id)
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Projects")
        .task {
            await viewModel.loadProjects()
        }
    }
}
