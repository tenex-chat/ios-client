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
        TabView {
            threadsTab

            docsTab

            agentsTab

            feedTab
        }
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
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
    @Environment(AuthManager.self) private var authManager
    @State private var showingSettings = false

    private let project: Project

    private var threadsTab: some View {
        ThreadListView(
            projectID: project.coordinate,
            userPubkey: authManager.currentUser?.pubkey
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
