//
// FeedTabViewModel.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation
import NDKSwiftCore
import Observation

// MARK: - FeedTabViewModel

/// View model for the Feed Tab
/// Shows all events that tag the project
@MainActor
@Observable
public final class FeedTabViewModel {
    // MARK: Lifecycle

    /// Initialize the feed tab view model
    /// - Parameters:
    ///   - ndk: The NDK instance
    ///   - projectID: The project identifier
    public init(ndk: NDK, projectID: String) {
        self.ndk = ndk
        self.projectID = projectID
    }

    // MARK: Public

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
    public func subscribe() {
        let filter = NDKFilter(tags: ["a": [projectID]])
        subscription = ndk.subscribe(filter: filter)
    }

    // MARK: Internal

    private(set) var subscription: NDKSubscription<NDKEvent>?

    // MARK: Private

    private let ndk: NDK
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
