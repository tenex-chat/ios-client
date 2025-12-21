//
// ThreadListViewModel.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation
import NDKSwiftCore
import Observation
import os
import TENEXCore
import TENEXShared

// MARK: - ThreadListViewModel

/// View model for the thread list screen
@MainActor
@Observable
public final class ThreadListViewModel {
    // MARK: Lifecycle

    /// Initialize the thread list view model
    /// - Parameters:
    ///   - ndk: The NDK instance for fetching threads
    ///   - projectID: The project addressable coordinate (kind:pubkey:dTag)
    ///   - filtersStore: The filters store for managing thread filters
    ///   - currentUserPubkey: The current user's pubkey (for needs-response filtering)
    ///   - archiveStorage: Storage for archived thread IDs
    public init(
        ndk: NDK,
        projectID: String,
        filtersStore: ThreadFiltersStore,
        currentUserPubkey: String?,
        archiveStorage: ThreadArchiveStorage = UserDefaultsThreadArchiveStorage()
    ) {
        self.ndk = ndk
        self.projectID = projectID
        self.filtersStore = filtersStore
        self.currentUserPubkey = currentUserPubkey
        self.archiveStorage = archiveStorage
        self.store = ProjectConversationStore(ndk: ndk, projectCoordinate: projectID)
    }

    // MARK: Public

    /// Whether to show archived threads in the main list
    public var showArchived: Bool = false

    /// Get thread event for navigation (async)
    /// - Parameter threadID: The thread ID
    /// - Returns: The NDKEvent for the thread, or nil
    public func getThreadEvent(for threadID: String) async -> NDKEvent? {
        await store.getThreadEvent(for: threadID)
    }

    /// The list of threads (already processed by store, just apply filters)
    public var threads: [ThreadSummary] {
        var filteredThreads = showArchived ? store.sortedThreads : filterArchivedThreads(from: store.sortedThreads)

        // Apply time-based filter if one is set
        let activeFilter = filtersStore.getFilter(for: projectID)
        if let filter = activeFilter {
            filteredThreads = applyFilter(filter, to: filteredThreads)
        }

        return filteredThreads
    }

    /// The current error message, if any
    public var errorMessage: String? {
        store.subscription?.error?.localizedDescription
    }

    /// Whether there are any archived threads
    public var hasArchivedThreads: Bool {
        !archiveStorage.archivedThreadIDs().isEmpty
    }

    /// Count of archived threads
    public var archivedThreadsCount: Int {
        archiveStorage.archivedThreadIDs().count
    }

    /// Get archived threads with summaries
    public var archivedThreads: [ThreadSummary] {
        let archivedIDs = archiveStorage.archivedThreadIDs()
        return store.sortedThreads.filter { archivedIDs.contains($0.id) }
    }

    /// Subscribe to all thread-related events
    public func subscribe() {
        Logger().info("[ThreadListViewModel] subscribe() called for projectID: \(self.projectID)")
        store.subscribe()
        Logger().info("[ThreadListViewModel] Subscription created")
    }

    /// Restart all subscriptions (useful when they get stuck)
    public func restartSubscriptions() {
        store.restartSubscriptions()
    }

    // MARK: Private

    /// Archive a thread (hide from list)
    /// - Parameter id: The thread ID to archive
    public func archiveThread(id: String) async {
        archiveStorage.archive(threadID: id)
    }

    /// Unarchive a thread (restore to list)
    /// - Parameter id: The thread ID to unarchive
    public func unarchiveThread(id: String) async {
        archiveStorage.unarchive(threadID: id)
    }

    // MARK: Internal

    /// The underlying conversation store (exposed for debug tools)
    let store: ProjectConversationStore

    private let ndk: NDK
    private let projectID: String
    private let filtersStore: ThreadFiltersStore
    private let currentUserPubkey: String?
    private let archiveStorage: ThreadArchiveStorage

    /// Filter out archived threads
    private func filterArchivedThreads(from threads: [ThreadSummary]) -> [ThreadSummary] {
        let archivedIDs = archiveStorage.archivedThreadIDs()
        return threads.filter { !archivedIDs.contains($0.id) }
    }

    /// Apply the selected filter to the thread list
    /// - Parameters:
    ///   - filter: The filter to apply
    ///   - threads: The threads to filter
    /// - Returns: The filtered threads
    private func applyFilter(
        _ filter: ThreadFilter,
        to threads: [ThreadSummary]
    ) -> [ThreadSummary] {
        let now = Date()
        let threshold = filter.thresholdSeconds

        if filter.isNeedsResponseFilter {
            return applyNeedsResponseFilter(threads: threads, threshold: threshold, now: now)
        } else {
            return applyActivityFilter(threads: threads, threshold: threshold, now: now)
        }
    }

    /// Apply activity filter (1h, 4h, 1d)
    /// Uses ThreadSummary.lastActivity which is already computed
    private func applyActivityFilter(
        threads: [ThreadSummary],
        threshold: TimeInterval,
        now: Date
    ) -> [ThreadSummary] {
        threads.filter { thread in
            let timeSinceLastActivity = now.timeIntervalSince(thread.lastActivity)
            return timeSinceLastActivity <= threshold
        }
    }

    /// Apply needs-response filter
    /// Uses lastReplyByThreadAndAuthor from state snapshot
    private func applyNeedsResponseFilter(
        threads: [ThreadSummary],
        threshold: TimeInterval,
        now: Date
    ) -> [ThreadSummary] {
        guard let userPubkey = currentUserPubkey else {
            return threads
        }

        let authorReplies = store.state.lastReplyByThreadAndAuthor

        return threads.filter { thread in
            guard let threadReplies = authorReplies[thread.id] else {
                return false
            }

            let userLastReply = threadReplies[userPubkey]
            let otherLastReply = threadReplies
                .filter { $0.key != userPubkey }
                .values
                .max()

            guard let lastOtherReply = otherLastReply else {
                return false
            }

            // If user replied after last other reply, no response needed
            if let userReply = userLastReply, userReply > lastOtherReply {
                return false
            }

            // Check if enough time has passed since other's reply
            let timeSinceOtherReply = now.timeIntervalSince(lastOtherReply)
            return timeSinceOtherReply >= threshold
        }
    }
}
