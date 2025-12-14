//
// DocsTabViewModel.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation
import NDKSwiftCore
import Observation

// MARK: - DocsTabViewModel

/// View model for the Docs Tab
/// Shows kind 30023 (long-form articles) that tag the project
@MainActor
@Observable
public final class DocsTabViewModel {
    // MARK: Lifecycle

    /// Initialize the docs tab view model
    /// - Parameters:
    ///   - ndk: The NDK instance
    ///   - projectID: The project identifier
    public init(ndk: NDK, projectID: String) {
        self.ndk = ndk
        self.projectID = projectID
    }

    // MARK: Public

    /// Search query for filtering documents
    public var searchQuery = ""

    /// All documents (kind 30023) from the subscription
    public var documents: [NDKEvent] {
        subscription?.data.filter { $0.kind == 30_023 } ?? []
    }

    /// Filtered and sorted documents based on search
    public var filteredDocuments: [NDKEvent] {
        var result = documents

        // Apply search filter
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        if !query.isEmpty {
            result = result.filter { documentMatchesSearch($0, query: query) }
        }

        // Sort by created_at (newest first)
        return result.sorted { $0.createdAt > $1.createdAt }
    }

    /// Subscribe to project documents (kind 30023)
    public func subscribe() {
        let filter = NDKFilter(
            kinds: [30_023],
            tags: ["a": [projectID]]
        )
        subscription = ndk.subscribe(filter: filter)
    }

    // MARK: Internal

    private(set) var subscription: NDKSubscription<NDKEvent>?

    // MARK: Private

    private let ndk: NDK
    private let projectID: String

    /// Check if a document matches the search query
    private func documentMatchesSearch(_ event: NDKEvent, query: String) -> Bool {
        let lowerQuery = query.lowercased()

        // Check title
        if let title = event.tagValue("title"), title.lowercased().contains(lowerQuery) {
            return true
        }

        // Check summary
        if let summary = event.tagValue("summary"), summary.lowercased().contains(lowerQuery) {
            return true
        }

        // Check content
        if event.content.lowercased().contains(lowerQuery) {
            return true
        }

        // Check hashtags
        let hashtags = event.tags(withName: "t").compactMap { $0[safe: 1] }
        for hashtag in hashtags where hashtag.lowercased().contains(lowerQuery) {
            return true
        }

        return false
    }
}
