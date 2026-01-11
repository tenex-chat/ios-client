//
// DocsTabViewModel.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation
import NDKSwiftCore
import Observation
import TENEXCore

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

    /// All document events (kind 30023) from the feed
    public var documentEvents: [NDKEvent] {
        feed.events.filter { $0.kind == 30_023 }
    }

    /// All documents parsed from events
    public var documents: [Document] {
        documentEvents.compactMap { Document.from(event: $0) }
    }

    /// Filtered and sorted documents based on search
    public var filteredDocuments: [Document] {
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
        let filter = Document.filter(for: projectID)
        let subscription = ndk.subscribe(filter: filter)
        feed.observe(subscription)
    }

    // MARK: Private

    private let ndk: NDK
    private let projectID: String
    private let feed = NDKFeed()

    /// Check if a document matches the search query
    private func documentMatchesSearch(_ document: Document, query: String) -> Bool {
        let lowerQuery = query.lowercased()

        // Check title
        if document.title.lowercased().contains(lowerQuery) {
            return true
        }

        // Check summary
        if let summary = document.summary, summary.lowercased().contains(lowerQuery) {
            return true
        }

        // Check content
        if document.content.lowercased().contains(lowerQuery) {
            return true
        }

        // Check hashtags
        for hashtag in document.hashtags where hashtag.lowercased().contains(lowerQuery) {
            return true
        }

        return false
    }
}
