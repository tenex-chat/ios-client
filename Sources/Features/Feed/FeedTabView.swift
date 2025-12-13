//
// FeedTabView.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import NDKSwiftCore
import SwiftUI

// MARK: - FeedTabView

/// View displaying the feed of project events
public struct FeedTabView: View {
    // MARK: Lifecycle

    /// Initialize the feed tab view
    /// - Parameters:
    ///   - projectID: The project identifier
    ///   - onEventClick: Optional callback when an event is tapped
    public init(projectID: String, onEventClick: ((NDKEvent) -> Void)? = nil) {
        self.projectID = projectID
        self.onEventClick = onEventClick
    }

    // MARK: Public

    public var body: some View {
        Group {
            if let ndk {
                contentView(ndk: ndk)
            } else {
                Text("NDK not available")
            }
        }
    }

    // MARK: Private

    @Environment(\.ndk) private var ndk
    @State private var viewModel: FeedTabViewModel?
    @State private var showFilterMenu = false

    private let projectID: String
    private let onEventClick: ((NDKEvent) -> Void)?

    private var emptyView: some View {
        VStack(spacing: 20) {
            Image(systemName: "tray.fill")
                .font(.system(size: 60))
                .foregroundStyle(.blue)

            Text("No events yet")
                .font(.headline)

            Text("Events from this project will appear here")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }

    private var noResultsView: some View {
        VStack(spacing: 20) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 60))
                .foregroundStyle(.blue)

            Text("No results found")
                .font(.headline)

            Text("Try adjusting your search terms")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            if let vm = viewModel {
                Button("Clear search") {
                    vm.searchQuery = ""
                }
                .buttonStyle(.bordered)
            }
        }
    }

    @ViewBuilder
    private func contentView(ndk: NDK) -> some View {
        let vm = viewModel ?? FeedTabViewModel(ndk: ndk, projectID: projectID)

        VStack(spacing: 0) {
            // Search bar - only show when there are events
            if !vm.events.isEmpty {
                FeedSearchBar(
                    searchQuery: Binding(
                        get: { vm.searchQuery },
                        set: { vm.searchQuery = $0 }
                    ),
                    selectedAuthor: Binding(
                        get: { vm.selectedAuthor },
                        set: { vm.selectedAuthor = $0 }
                    ),
                    groupThreads: Binding(
                        get: { vm.groupThreads },
                        set: { vm.groupThreads = $0 }
                    ),
                    uniqueAuthors: vm.uniqueAuthors,
                    ndk: ndk
                )
            }

            // Event list or empty states
            if vm.events.isEmpty {
                emptyView
            } else if vm.filteredEvents.isEmpty {
                noResultsView
            } else {
                eventList(viewModel: vm, ndk: ndk)
            }
        }
        .task {
            if viewModel == nil {
                viewModel = vm
            }
            await vm.subscribe()
        }
    }

    private func eventList(viewModel: FeedTabViewModel, ndk: NDK) -> some View {
        List {
            ForEach(viewModel.filteredEvents, id: \.id) { event in
                FeedEventRow(event: event, ndk: ndk)
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onEventClick?(event)
                    }
            }
        }
        .listStyle(.plain)
    }
}
