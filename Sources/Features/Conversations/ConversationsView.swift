//
// ConversationsView.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import NDKSwiftCore
import SwiftUI
import TENEXCore

/// The main Conversations tab showing recent conversations with project and time filtering
public struct ConversationsView: View {
    // MARK: Lifecycle

    public init() {}

    // MARK: Public

    public var body: some View {
        Group {
            if let ndk {
                #if os(macOS)
                macOSBody(ndk: ndk, dataStore: dataStore)
                #else
                iOSBody(ndk: ndk, dataStore: dataStore)
                #endif
            } else {
                ProgressView("Loading...")
            }
        }
        .navigationTitle("Conversations")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            toolbarContent
        }
    }

    // MARK: Private

    @Environment(DataStore.self) private var dataStore
    @Environment(NDKAuthManager.self) private var authManager
    @Environment(\.ndk) private var ndk

    @State private var viewModel: ConversationsViewModel?
    @State private var selectedThreadID: String?
    @State private var filterStore = ConversationsFilterStore()
    @State private var showingProjectPicker = false
    /// Visibility tracking to prevent expensive re-computation when not visible
    @State private var isVisible = true

    // MARK: - macOS Body

    @ViewBuilder
    private func macOSBody(ndk: NDK, dataStore: DataStore) -> some View {
        let vm = viewModel ?? ConversationsViewModel(
            dataStore: dataStore,
            ndk: ndk,
            filterStore: filterStore
        )

        NavigationSplitView {
            conversationList(viewModel: vm)
        } detail: {
            if let selectedThreadID {
                destinationView(threadID: selectedThreadID, viewModel: vm)
            } else {
                emptyDetailView(viewModel: vm)
            }
        }
        .task {
            if self.viewModel == nil {
                self.viewModel = vm
            }
        }
        .sheet(isPresented: $showingProjectPicker) {
            NewThreadProjectPickerSheet(projects: vm.availableProjects)
        }
    }

    // MARK: - iOS Body

    @ViewBuilder
    private func iOSBody(ndk: NDK, dataStore: DataStore) -> some View {
        let vm = viewModel ?? ConversationsViewModel(
            dataStore: dataStore,
            ndk: ndk,
            filterStore: filterStore
        )

        List {
            // Only access observable properties when visible to prevent
            // expensive re-computation when navigated away from this view
            if isVisible {
                if vm.sortedThreadIDs.isEmpty {
                    emptyListContent(viewModel: vm)
                } else {
                    conversationListContent(viewModel: vm)
                }
            } else {
                // Placeholder when not visible - breaks observation chain
                Color.clear
            }
        }
        .listStyle(.plain)
        .onAppear { isVisible = true }
        .onDisappear { isVisible = false }
        .task {
            if self.viewModel == nil {
                self.viewModel = vm
            }
        }
        .sheet(isPresented: $showingProjectPicker) {
            NewThreadProjectPickerSheet(projects: vm.availableProjects)
        }
    }

    // MARK: - Toolbar Content

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        // Trailing: New thread button, then filter button
        ToolbarItem(placement: .primaryAction) {
            if authManager.activePubkey != nil {
                HStack(spacing: 12) {
                    Button {
                        showingProjectPicker = true
                    } label: {
                        Image(systemName: "plus")
                    }

                    if let vm = viewModel {
                        filterMenu(viewModel: vm)
                    }
                }
            }
        }
    }

    // MARK: - Filter Menu

    /// Whether any filter is active
    private func hasActiveFilter(_ viewModel: ConversationsViewModel) -> Bool {
        viewModel.hasProjectFilter || viewModel.currentTimeFilter != .all
    }

    @ViewBuilder
    private func filterMenu(viewModel: ConversationsViewModel) -> some View {
        Menu {
            projectFilterSection(viewModel: viewModel)
            timeFilterSection(viewModel: viewModel)
        } label: {
            Image(systemName: hasActiveFilter(viewModel)
                ? "line.3.horizontal.decrease.circle.fill"
                : "line.3.horizontal.decrease.circle")
        }
    }

    @ViewBuilder
    private func projectFilterSection(viewModel: ConversationsViewModel) -> some View {
        Section("Projects") {
            Button {
                viewModel.clearProjectFilter()
            } label: {
                HStack {
                    Text("All Projects")
                    if !viewModel.hasProjectFilter {
                        Spacer()
                        Image(systemName: "checkmark")
                    }
                }
            }

            ForEach(viewModel.availableProjects) { project in
                projectFilterButton(project: project, viewModel: viewModel)
            }
        }
    }

    @ViewBuilder
    private func projectFilterButton(project: Project, viewModel: ConversationsViewModel) -> some View {
        Button {
            viewModel.toggleProject(project.coordinate)
        } label: {
            HStack(spacing: 8) {
                Circle()
                    .fill(project.color)
                    .frame(width: 8, height: 8)
                Text(project.title)
                Spacer()
                if viewModel.isProjectSelected(project.coordinate), viewModel.hasProjectFilter {
                    Image(systemName: "checkmark")
                }
            }
        }
    }

    @ViewBuilder
    private func timeFilterSection(viewModel: ConversationsViewModel) -> some View {
        Section("Time") {
            ForEach(TimeFilter.allCases) { filter in
                Button {
                    viewModel.setTimeFilter(filter)
                } label: {
                    HStack {
                        Label(filter.displayName, systemImage: filter.systemImage)
                        if filter == viewModel.currentTimeFilter {
                            Spacer()
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        }
    }

    // MARK: - Conversation List

    @ViewBuilder
    private func conversationList(viewModel: ConversationsViewModel) -> some View {
        List(selection: $selectedThreadID) {
            if viewModel.sortedThreadIDs.isEmpty {
                emptyListContent(viewModel: viewModel)
            } else {
                ForEach(viewModel.sortedThreadIDs, id: \.self) { threadID in
                    if let latestMessage = viewModel.latestMessage(for: threadID) {
                        conversationButton(
                            threadID: threadID,
                            latestMessage: latestMessage,
                            viewModel: viewModel
                        )
                    }
                }
            }
        }
        .listStyle(.plain)
    }

    @ViewBuilder
    private func conversationListContent(viewModel: ConversationsViewModel) -> some View {
        ForEach(viewModel.sortedThreadIDs, id: \.self) { threadID in
            if let latestMessage = viewModel.latestMessage(for: threadID) {
                let hierarchyInfo = viewModel.getHierarchyInfo(for: threadID)
                NavigationLink {
                    destinationView(threadID: threadID, viewModel: viewModel)
                } label: {
                    ConversationRow(
                        threadID: threadID,
                        project: viewModel.getProject(for: threadID),
                        latestMessage: latestMessage,
                        conversationMetadata: viewModel.getConversationMetadata(for: threadID),
                        depth: hierarchyInfo.depth,
                        hasChildren: hierarchyInfo.hasChildren,
                        childCount: hierarchyInfo.childCount
                    )
                }
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
            }
        }
    }

    @ViewBuilder
    private func conversationButton(
        threadID: String,
        latestMessage: Message,
        viewModel: ConversationsViewModel
    ) -> some View {
        let hierarchyInfo = viewModel.getHierarchyInfo(for: threadID)
        Button {
            selectedThreadID = threadID
        } label: {
            ConversationRow(
                threadID: threadID,
                project: viewModel.getProject(for: threadID),
                latestMessage: latestMessage,
                conversationMetadata: viewModel.getConversationMetadata(for: threadID),
                depth: hierarchyInfo.depth,
                hasChildren: hierarchyInfo.hasChildren,
                childCount: hierarchyInfo.childCount
            )
        }
        .buttonStyle(.plain)
        .tag(threadID)
        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
    }

    // MARK: - Empty States

    @ViewBuilder
    private func emptyListContent(viewModel: ConversationsViewModel) -> some View {
        ContentUnavailableView(
            emptyTitle(viewModel: viewModel),
            systemImage: emptySystemImage(viewModel: viewModel),
            description: Text(emptyDescription(viewModel: viewModel))
        )
    }

    @ViewBuilder
    private func emptyDetailView(viewModel: ConversationsViewModel) -> some View {
        ContentUnavailableView(
            "Select a Conversation",
            systemImage: "bubble.left.and.bubble.right",
            description: Text("Choose a conversation from the list")
        )
    }

    private func emptyTitle(viewModel: ConversationsViewModel) -> String {
        if viewModel.hasProjectFilter || viewModel.currentTimeFilter != .all {
            return "No Matching Conversations"
        }
        return "No Conversations"
    }

    private func emptySystemImage(viewModel: ConversationsViewModel) -> String {
        if viewModel.hasProjectFilter {
            return "line.3.horizontal.decrease.circle"
        } else if viewModel.currentTimeFilter != .all {
            return "clock"
        }
        return "bubble.left.and.bubble.right"
    }

    private func emptyDescription(viewModel: ConversationsViewModel) -> String {
        if viewModel.hasProjectFilter, viewModel.currentTimeFilter != .all {
            return "No conversations match your project and time filters. Try adjusting your filters."
        } else if viewModel.hasProjectFilter {
            return "No conversations in the selected projects. Try selecting different projects."
        } else if viewModel.currentTimeFilter != .all {
            return "No conversations in the selected time range. Try a longer time period."
        }
        return "Recent conversations across all projects will appear here."
    }

    // MARK: - Navigation

    @ViewBuilder
    private func destinationView(threadID: String, viewModel: ConversationsViewModel) -> some View {
        // Use thread ID directly - no loading state needed, event-based system shows state as-is
        if let project = viewModel.getProject(for: threadID),
           let userPubkey = authManager.activePubkey {
            ChatView(
                threadID: threadID,
                projectReference: project.coordinate,
                currentUserPubkey: userPubkey
            )
        } else {
            // Fallback only if we can't determine the project
            ContentUnavailableView(
                "Thread Not Available",
                systemImage: "exclamationmark.triangle",
                description: Text("Unable to determine the project for this thread.")
            )
        }
    }
}

// MARK: - NewThreadProjectPickerSheet

/// Sheet for selecting a project to create a new thread in
struct NewThreadProjectPickerSheet: View {
    // MARK: Internal

    let projects: [Project]

    var body: some View {
        NavigationStack {
            List(projects) { project in
                NavigationLink {
                    if let userPubkey = authManager.activePubkey {
                        ChatView(
                            threadEvent: nil,
                            projectReference: project.coordinate,
                            currentUserPubkey: userPubkey
                        )
                    }
                } label: {
                    HStack(spacing: 12) {
                        Circle()
                            .fill(project.color)
                            .frame(width: 12, height: 12)

                        Text(project.title)
                            .font(.body)
                    }
                }
            }
            .navigationTitle("New Thread")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: Private

    @Environment(\.dismiss) private var dismiss
    @Environment(NDKAuthManager.self) private var authManager
}
