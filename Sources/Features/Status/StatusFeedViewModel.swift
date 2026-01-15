//
// StatusFeedViewModel.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation
import NDKSwiftCore
import os
import TENEXCore

/// Manages the status feed by subscribing to kind:513 conversation metadata events
@MainActor
@Observable
public final class StatusFeedViewModel {
    // MARK: Lifecycle

    /// Initialize with dependencies
    /// - Parameters:
    ///   - dataStore: The data store for accessing project data
    ///   - ndk: The NDK instance for fetching metadata events
    public init(dataStore: DataStore, ndk: NDK) {
        self.dataStore = dataStore
        self.ndk = ndk
        self.metadataFetcher = MetadataFetcher(ndk: ndk)
    }

    // MARK: Public

    /// All conversation metadata items, sorted by latest timestamp (newest first)
    public private(set) var items: [ConversationMetadata] = []

    /// Whether the feed is currently loading
    public private(set) var isLoading = false

    /// Start subscribing to conversation metadata events
    public func startSubscription() {
        guard !isSubscribed else {
            return
        }
        isSubscribed = true
        isLoading = true

        subscriptionTask = Task {
            await subscribeToMetadataEvents()
        }
    }

    /// Stop the subscription
    public func stopSubscription() {
        subscriptionTask?.cancel()
        subscriptionTask = nil
        subscription = nil
        isSubscribed = false
    }

    /// Get the project for a conversation metadata item
    /// - Parameter metadata: The conversation metadata
    /// - Returns: The Project if found
    public func getProject(for metadata: ConversationMetadata) -> Project? {
        guard let coordinate = metadata.projectCoordinate else {
            return nil
        }

        // Try to find project by coordinate
        return dataStore.projects.first { $0.coordinate == coordinate }
    }

    /// Get the thread event for navigation
    /// - Parameter metadata: The conversation metadata
    /// - Returns: The NDKEvent if cached
    public func getThreadEvent(for metadata: ConversationMetadata) -> NDKEvent? {
        metadataFetcher.getThreadEvent(for: metadata.threadID)
    }

    /// Fetch thread event for a conversation if not already cached
    /// - Parameter threadID: The thread ID to fetch
    public func fetchThreadEventIfNeeded(for threadID: String) {
        metadataFetcher.prefetchThreadEvent(for: threadID)
    }

    // MARK: Private

    private let dataStore: DataStore
    private let ndk: NDK
    private let metadataFetcher: MetadataFetcher
    private let logger = Logger(subsystem: "com.tenex.ios", category: "StatusFeed")

    private var subscription: NDKSubscription<NDKEvent>?
    private var subscriptionTask: Task<Void, Never>?
    private var isSubscribed = false
    private var conversationMap: [String: ConversationMetadata] = [:]

    private func subscribeToMetadataEvents() async {
        logger.debug("Starting subscription to kind:513 metadata events")

        let filter = ConversationMetadata.allFilter()
        subscription = ndk.subscribe(filter: filter)

        guard let subscription else {
            logger.error("Failed to create subscription")
            isLoading = false
            return
        }

        for await events in subscription.events {
            isLoading = false

            for event in events {
                processEvent(event)
            }
            updateItems()
        }
    }

    private func processEvent(_ event: NDKEvent) {
        guard let metadata = ConversationMetadata.from(event: event) else {
            logger.debug("Failed to parse metadata from event")
            return
        }

        let existing = conversationMap[metadata.threadID]

        // Update if newer or doesn't exist
        if existing == nil {
            conversationMap[metadata.threadID] = metadata
            logger.debug("Added new metadata for thread: \(metadata.threadID)")
        } else if let existingMetadata = existing, metadata.createdAt > existingMetadata.createdAt {
            conversationMap[metadata.threadID] = metadata
            logger.debug("Updated metadata for thread: \(metadata.threadID)")
        } else if let existingMetadata = existing {
            // Older event - merge fields that are missing
            if existingMetadata.title == nil, let newTitle = metadata.title {
                let updated = ConversationMetadata(
                    threadID: existingMetadata.threadID,
                    pubkey: existingMetadata.pubkey,
                    title: newTitle,
                    summary: existingMetadata.summary ?? metadata.summary,
                    statusLabel: existingMetadata.statusLabel ?? metadata.statusLabel,
                    statusCurrentActivity: existingMetadata.statusCurrentActivity ?? metadata.statusCurrentActivity,
                    tags: existingMetadata.tags.isEmpty ? metadata.tags : existingMetadata.tags,
                    projectCoordinate: existingMetadata.projectCoordinate ?? metadata.projectCoordinate,
                    createdAt: existingMetadata.createdAt,
                    event: existingMetadata.event
                )
                conversationMap[metadata.threadID] = updated
            }
        }
    }

    private func updateItems() {
        // Sort by latest timestamp descending (newest first)
        items = Array(conversationMap.values)
            .sorted { $0.createdAt > $1.createdAt }
    }
}
