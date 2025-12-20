//
// FeedTabView.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import NDKSwiftCore
import SwiftUI

// MARK: - FeedTabView

/// View displaying the feed of project events
/// This is a "dumb" view that only knows how to display data
/// All business logic is handled by the FeedTabViewModel
public struct FeedTabView: View {
    // MARK: Lifecycle

    /// Initialize the feed tab view
    /// - Parameters:
    ///   - viewModel: The view model managing feed state and data
    ///   - onEventClick: Optional callback when an event is tapped
    public init(
        viewModel: FeedTabViewModel,
        onEventClick: ((NDKEvent) -> Void)? = nil
    ) {
        self.viewModel = viewModel
        self.onEventClick = onEventClick
    }

    // MARK: Public

    public var body: some View {
        contentView
            .task {
                await viewModel.subscribe()
            }
            .onDisappear {
                viewModel.cleanup()
            }
    }

    // MARK: Private

    @Environment(\.ndk) private var ndk

    @Bindable private var viewModel: FeedTabViewModel
    private let onEventClick: ((NDKEvent) -> Void)?

    // MARK: - Content View

    @ViewBuilder
    private var contentView: some View {
        switch viewModel.state {
        case .idle:
            emptyView

        case .loading:
            loadingView

        case .loaded:
            loadedContent

        case let .error(error):
            errorView(error: error)
        }
    }

    // MARK: - State Views

    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)

            Text("Loading feed...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private func errorView(error: FeedServiceError) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.orange)

            Text("Error Loading Feed")
                .font(.headline)

            Text(error.localizedDescription)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button("Retry") {
                Task {
                    await viewModel.retry()
                }
            }
            .buttonStyle(.borderedProminent)
        }
    }

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

            Button("Clear Filters") {
                viewModel.clearFilters()
            }
            .buttonStyle(.bordered)
        }
    }

    // MARK: - Loaded Content

    @ViewBuilder
    private var loadedContent: some View {
        VStack(spacing: 0) {
            // Search bar - only show when there are events
            if !viewModel.events.isEmpty, let ndk {
                FeedSearchBar(
                    searchQuery: $viewModel.searchQuery,
                    selectedAuthor: $viewModel.selectedAuthor,
                    groupThreads: $viewModel.groupThreads,
                    uniqueAuthors: viewModel.uniqueAuthors,
                    ndk: ndk
                )
            }

            // Event list or empty/no-results states
            if viewModel.events.isEmpty {
                emptyView
            } else if viewModel.filteredEvents.isEmpty {
                noResultsView
            } else if let ndk {
                eventList(ndk: ndk)
            }
        }
    }

    private func eventList(ndk: NDK) -> some View {
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
