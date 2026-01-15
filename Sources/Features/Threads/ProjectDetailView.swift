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
/// Note: Conversations tab removed - use main Conversations tab with project filter instead
public struct ProjectDetailView: View {
    // MARK: Lifecycle

    /// Initialize the project detail view
    /// - Parameter project: The project to display
    public init(project: Project) {
        self.project = project
    }

    // MARK: Public

    public var body: some View {
        TabView(selection: self.$selectedTab) {
            self.docsTab
                .tag(0)

            self.agentsTab
                .tag(1)

            self.feedTab
                .tag(2)
        }
        #if os(iOS)
        .toolbar(.hidden, for: .tabBar)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .secondaryAction) {
                self.settingsMenu
            }
        }
        .sheet(isPresented: self.$showingSettings) {
            ProjectSettingsView(project: self.project)
        }
    }

    // MARK: Private

    @Environment(\.ndk) private var ndk
    @Environment(NDKAuthManager.self) private var authManager
    @State private var showingSettings = false
    @State private var selectedTab = 0

    private let project: Project

    private var docsTab: some View {
        DocsTabView(projectID: self.project.coordinate)
            .navigationTitle(self.project.title)
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
                        projectID: self.project.coordinate
                    )
                )
                .navigationTitle(self.project.title)
            } else {
                Text("NDK not available")
                    .navigationTitle(self.project.title)
            }
        }
        .tabItem {
            Label("Agents", systemImage: "person.2.fill")
        }
    }

    private var feedTab: some View {
        Group {
            if let ndk {
                FeedTabViewFactory.create(
                    ndk: ndk,
                    projectID: self.project.coordinate
                )
                .navigationTitle(self.project.title)
            } else {
                Text("NDK not available")
                    .navigationTitle(self.project.title)
            }
        }
        .tabItem {
            Label("Feed", systemImage: "list.bullet")
        }
    }

    @ViewBuilder private var settingsMenu: some View {
        Menu {
            Button {
                self.showingSettings = true
            } label: {
                Label("Project Settings", systemImage: "gearshape")
            }
        } label: {
            Label("Settings", systemImage: "gear")
        }
    }
}
