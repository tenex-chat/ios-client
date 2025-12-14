//
// ProjectDetailView.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import NDKSwiftCore
import SwiftUI
import TENEXCore

// MARK: - ProjectDetailView

/// View displaying project details with tabbed interface
public struct ProjectDetailView: View {
    // MARK: Lifecycle

    /// Initialize the project detail view
    /// - Parameter project: The project to display
    public init(project: Project) {
        self.project = project
    }

    // MARK: Public

    public var body: some View {
        TabView(selection: $selectedTab) {
            threadsTab
                .tag(0)

            docsTab
                .tag(1)

            agentsTab
                .tag(2)

            feedTab
                .tag(3)
        }
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            // Show "New Thread" button only on threads tab
            if selectedTab == 0, let userPubkey = authManager.activePubkey {
                ToolbarItem(placement: .primaryAction) {
                    NavigationLink {
                        ChatView(
                            threadEvent: nil,
                            projectReference: project.coordinate,
                            currentUserPubkey: userPubkey
                        )
                    } label: {
                        Label("New Thread", systemImage: "plus")
                    }
                }
            }

            ToolbarItem(placement: .secondaryAction) {
                Button {
                    showingSettings = true
                } label: {
                    Label("Settings", systemImage: "gear")
                }
            }
        }
        .sheet(isPresented: $showingSettings) {
            ProjectSettingsView(project: project)
        }
    }

    // MARK: Private

    @Environment(\.ndk) private var ndk
    @Environment(NDKAuthManager.self) private var authManager
    @State private var showingSettings = false
    @State private var selectedTab = 0

    private let project: Project

    private var threadsTab: some View {
        ThreadListView(
            projectID: project.coordinate,
            userPubkey: authManager.activePubkey
        )
        .navigationTitle(project.title)
        .tabItem {
            Label("Threads", systemImage: "message.fill")
        }
    }

    private var docsTab: some View {
        DocsTabView(projectID: project.coordinate)
            .navigationTitle(project.title)
            .tabItem {
                Label("Docs", systemImage: "doc.fill")
            }
    }

    private var agentsTab: some View {
        Group {
            if let ndk {
                AgentsTabView(
                    viewModel: AgentsTabViewModel(
                        ndk: ndk,
                        projectID: project.coordinate
                    )
                )
                .navigationTitle(project.title)
            } else {
                Text("NDK not available")
                    .navigationTitle(project.title)
            }
        }
        .tabItem {
            Label("Agents", systemImage: "person.2.fill")
        }
    }

    private var feedTab: some View {
        FeedTabView(projectID: project.coordinate)
            .navigationTitle(project.title)
            .tabItem {
                Label("Feed", systemImage: "list.bullet")
            }
    }
}
