//
// FeedTabViewModel.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation
import NDKSwiftCore
import Observation

// MARK: - FeedViewState

/// Represents the current state of the feed view
public enum FeedViewState: Equatable {
    case idle
    case loading
    case loaded
    case error(FeedServiceError)

    public static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.loading, .loading), (.loaded, .loaded):
            return true
        case let (.error(lhsError), .error(rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        default:
            return false
        }
    }
}

// MARK: - FeedTabViewModel

/// View model for the Feed Tab
/// Shows all events that tag the project
/// Follows MVVM architecture with clear separation of concerns
@MainActor
@Observable
public final class FeedTabViewModel {
    // MARK: Lifecycle

    /// Initialize the feed tab view model
    /// - Parameters:
    ///   - service: The feed service for network operations
    ///   - projectID: The project identifier
    public init(service: FeedServiceProtocol, projectID: String) {
        self.service = service
        self.projectID = projectID
    }

    // MARK: Public

    /// Current view state
    public private(set) var state: FeedViewState = .idle

    /// Search query
    public var searchQuery = ""

    /// Selected author filter
    public var selectedAuthor: String?

    /// Whether to group threads
    public var groupThreads = false

    /// All events from the feed (filtered to exclude unwanted kinds)
    public var events: [NDKEvent] {
        subscription?.data.filter { shouldIncludeEvent($0) } ?? []
    }

    /// Filtered and sorted events based on search, author, and thread grouping
    public var filteredEvents: [NDKEvent] {
        var result = events

        // Apply thread grouping if enabled
        if groupThreads {
            result = deduplicateByThreadID(result)
        }

        // Apply author filter
        if let author = selectedAuthor {
            result = result.filter { $0.pubkey == author }
        }

        // Apply search filter
        if !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            result = result.filter { eventMatchesSearch($0, query: searchQuery) }
        }

        // Sort by created_at (newest first)
        return result.sorted { ($0.createdAt) > ($1.createdAt) }
    }

    /// Unique authors from all events (limited to 15)
    public var uniqueAuthors: [String] {
        let pubkeys = Set(events.map(\.pubkey))
        return Array(pubkeys.sorted()).prefix(15).map(\.self)
    }

    /// Subscribe to project events
    public func subscribe() async {
        guard state != .loading else {
            return
        }

        state = .loading

        do {
            subscription = try await service.subscribeToProject(projectID)
            state = .loaded
        } catch let error as FeedServiceError {
            state = .error(error)
        } catch {
            state = .error(.subscriptionFailed)
        }
    }

    /// Retry subscription after an error
    public func retry() async {
        await subscribe()
    }

    /// Clear search and filters
    public func clearFilters() {
        searchQuery = ""
        selectedAuthor = nil
    }

    /// Clean up when view disappears
    public func cleanup() {
        service.unsubscribe()
        subscription = nil
        state = .idle
    }

    // MARK: Internal

    private(set) var subscription: NDKSubscription<NDKEvent>?

    // MARK: Private

    private let service: FeedServiceProtocol
    private let projectID: String

    /// Check if an event should be included in the feed
    private func shouldIncludeEvent(_ event: NDKEvent) -> Bool {
        let kind = event.kind

        // Filter out kind 0 (metadata)
        if kind == 0 {
            return false
        }

        // Filter out ephemeral events (20000-29999)
        if kind >= 20_000, kind <= 29_999 {
            return false
        }

        return true
    }

    /// Check if an event matches the search query
    private func eventMatchesSearch(_ event: NDKEvent, query: String) -> Bool {
        let lowerQuery = query.lowercased()

        // Check event content
        if event.content.lowercased().contains(lowerQuery) {
            return true
        }

        // Check article title (kind 30023)
        if event.kind == 30_023, let title = event.tagValue("title") {
            if title.lowercased().contains(lowerQuery) {
                return true
            }
        }

        // Check thread title (kind 11)
        if event.kind == 11, let title = event.tagValue("title") {
            if title.lowercased().contains(lowerQuery) {
                return true
            }
        }

        // Check hashtags
        let hashtags = event.tags(withName: "t").compactMap { $0[safe: 1] }
        for hashtag in hashtags where hashtag.lowercased().contains(lowerQuery) {
            return true
        }

        return false
    }

    /// Deduplicate events by thread ID (E tag), keeping most recent per thread
    private func deduplicateByThreadID(_ events: [NDKEvent]) -> [NDKEvent] {
        var eventsByThreadID: [String?: [NDKEvent]] = [:]

        for event in events {
            let threadID = event.tagValue("E")
            var group = eventsByThreadID[threadID] ?? []
            group.append(event)
            eventsByThreadID[threadID] = group
        }

        var deduplicated: [NDKEvent] = []

        for (threadID, group) in eventsByThreadID {
            if threadID == nil {
                // No E tag - include all events
                deduplicated.append(contentsOf: group)
            } else {
                // Has E tag - only include most recent
                if let mostRecent = group.max(by: { $0.createdAt < $1.createdAt }) {
                    deduplicated.append(mostRecent)
                }
            }
        }

        return deduplicated
    }
}
