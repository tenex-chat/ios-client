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
        TabView(selection: self.$selectedTab) {
            self.threadsTab
                .tag(0)

            self.docsTab
                .tag(1)

            self.agentsTab
                .tag(2)

            self.feedTab
                .tag(3)
        }
        #if os(iOS)
        .toolbar(.hidden, for: .tabBar)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            // Show "New Thread" button only on threads tab
            if self.selectedTab == 0, let userPubkey = authManager.activePubkey {
                ToolbarItem(placement: .primaryAction) {
                    NavigationLink {
                        ChatView(
                            threadEvent: nil,
                            projectReference: self.project.coordinate,
                            currentUserPubkey: userPubkey
                        )
                    } label: {
                        Label("New Thread", systemImage: "plus")
                    }
                }
            }

            // Show filter button only on threads tab
            if self.selectedTab == 0 {
                ToolbarItem(placement: .secondaryAction) {
                    self.filterMenu
                }
            }

            ToolbarItem(placement: .secondaryAction) {
                Button {
                    self.showingSettings = true
                } label: {
                    Label("Settings", systemImage: "gear")
                }
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
    @State private var filtersStore = ThreadFiltersStore()

    private let project: Project

    private var threadsTab: some View {
        ThreadListView(
            projectID: self.project.coordinate,
            userPubkey: self.authManager.activePubkey,
            filtersStore: self.filtersStore
        )
        .navigationTitle(self.project.title)
        .tabItem {
            Label("Threads", systemImage: "message.fill")
        }
    }

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

    @ViewBuilder private var filterMenu: some View {
        let activeFilter = self.filtersStore.getFilter(for: self.project.coordinate)

        Menu {
            // Clear filter button
            Button {
                self.filtersStore.setFilter(nil, for: self.project.coordinate)
            } label: {
                Label("All conversations", systemImage: "circle")
            }

            Divider()

            // Activity filters section
            Section("Activity filters") {
                ForEach([ThreadFilter.oneHour, .fourHours, .oneDay], id: \.self) { filter in
                    Button {
                        self.filtersStore.setFilter(filter, for: self.project.coordinate)
                    } label: {
                        Label(filter.displayName, systemImage: filter.systemImage)
                    }
                }
            }

            Divider()

            // Needs response filters section
            Section("Response filters") {
                ForEach(
                    [ThreadFilter.needsResponseOneHour, .needsResponseFourHours, .needsResponseOneDay],
                    id: \.self
                ) { filter in
                    Button {
                        self.filtersStore.setFilter(filter, for: self.project.coordinate)
                    } label: {
                        Label(filter.displayName, systemImage: filter.systemImage)
                    }
                }
            }
        } label: {
            Label(
                activeFilter?.displayName ?? "Filter",
                systemImage: activeFilter != nil
                    ? "line.3.horizontal.decrease.circle.fill"
                    : "line.3.horizontal.decrease.circle"
            )
        }
    }
}
