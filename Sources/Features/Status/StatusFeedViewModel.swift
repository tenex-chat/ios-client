//
// StatusFeedViewModel.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation
import NDKSwiftCore
import os
import TENEXCore

/// Manages the status feed by reading from DataStore's centralized conversation metadata
/// NO LONGER creates its own subscription - uses DataStore as single source of truth
@MainActor
@Observable
public final class StatusFeedViewModel {
    // MARK: Lifecycle

    /// Initialize with dependencies
    /// - Parameters:
    ///   - dataStore: The data store (single source of truth for metadata)
    ///   - ndk: The NDK instance for fetching thread events
    public init(dataStore: DataStore, ndk: NDK) {
        self.dataStore = dataStore
        self.ndk = ndk
    }

    // MARK: Public

    /// All conversation metadata items from DataStore, sorted by latest timestamp (newest first)
    /// Reads directly from DataStore - no duplicate storage
    public var items: [ConversationMetadata] {
        dataStore.allConversationMetadata
    }

    /// Whether the feed is currently loading (based on DataStore having no data yet)
    public var isLoading: Bool {
        dataStore.conversationMetadata.isEmpty && dataStore.isLoadingProjects
    }

    /// Start subscription - now just a no-op since DataStore handles subscriptions
    /// Kept for API compatibility during transition
    public func startSubscription() {
        // DataStore manages subscriptions centrally - nothing to do here
        logger.debug("StatusFeedViewModel: Using DataStore for metadata (no local subscription)")
    }

    /// Stop subscription - now just a no-op since DataStore handles subscriptions
    /// Kept for API compatibility during transition
    public func stopSubscription() {
        // DataStore manages subscriptions centrally - nothing to do here
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
        threadEventCache[metadata.threadID]
    }

    /// Fetch thread event for a conversation if not already cached
    /// - Parameter threadID: The thread ID to fetch
    public func fetchThreadEventIfNeeded(for threadID: String) {
        guard threadEventCache[threadID] == nil else {
            return
        }

        Task {
            logger.debug("Fetching thread event: \(threadID)")
            let filter = NDKFilter(ids: [threadID], kinds: [1])
            let subscription = ndk.subscribe(filter: filter)

            for await events in subscription.events.prefix(1) {
                if let event = events.first {
                    threadEventCache[threadID] = event
                    logger.debug("Cached thread event: \(threadID)")
                }
            }
        }
    }

    // MARK: Private

    private let dataStore: DataStore
    private let ndk: NDK
    private let logger = Logger(subsystem: "com.tenex.ios", category: "StatusFeed")

    // Thread event cache for navigation (this is transient UI state, not global data)
    private var threadEventCache: [String: NDKEvent] = [:]
}
