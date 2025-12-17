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

    /// Map of thread ID to original NDKEvent (needed for ChatView navigation)
    public var threadEvents: [String: NDKEvent] {
        store.threadEvents
    }

    /// The list of threads (already processed by store, just apply filters)
    public var threads: [ThreadSummary] {
        var filteredThreads = filterArchivedThreads(from: store.sortedThreads)

        // Apply time-based filter if one is set
        let activeFilter = filtersStore.getFilter(for: projectID)
        if let filter = activeFilter {
            filteredThreads = applyFilter(filter, to: filteredThreads, messages: store.allMessages)
        }

        return filteredThreads
    }

    /// The current error message, if any
    public var errorMessage: String? {
        store.subscription?.error?.localizedDescription
    }

    /// Subscribe to all thread-related events
    public func subscribe() {
        Logger().info("[ThreadListViewModel] subscribe() called for projectID: \(self.projectID)")

        store.subscribe()

        // Process events as they arrive (events is AsyncStream<[NDKEvent]> - batches)
        subscriptionTask = Task {
            guard let subscription = store.subscription else {
                return
            }
            for await batch in subscription.events {
                for event in batch {
                    store.processEvent(event)
                }
            }
        }

        Logger().info("[ThreadListViewModel] Subscription created")
    }

    /// Restart all subscriptions (useful when they get stuck)
    public func restartSubscriptions() {
        subscriptionTask?.cancel()
        subscriptionTask = nil
        store.unsubscribe()
        subscribe()
    }

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

    // MARK: Private

    private let ndk: NDK
    private let projectID: String
    private let filtersStore: ThreadFiltersStore
    private let currentUserPubkey: String?
    private let archiveStorage: ThreadArchiveStorage
    private let store: ProjectConversationStore
    private var subscriptionTask: Task<Void, Never>?

    /// Filter out archived threads
    private func filterArchivedThreads(from threads: [ThreadSummary]) -> [ThreadSummary] {
        let archivedIDs = archiveStorage.archivedThreadIDs()
        return threads.filter { !archivedIDs.contains($0.id) }
    }

    /// Apply the selected filter to the thread list
    /// - Parameters:
    ///   - filter: The filter to apply
    ///   - threads: The threads to filter
    ///   - messages: The message events (kind:1111)
    /// - Returns: The filtered threads
    private func applyFilter(
        _ filter: ThreadFilter,
        to threads: [ThreadSummary],
        messages: [NDKEvent]
    ) -> [ThreadSummary] {
        let now = Date().timeIntervalSince1970
        let threshold = filter.thresholdSeconds

        if filter.isNeedsResponseFilter {
            return applyNeedsResponseFilter(threads: threads, messages: messages, threshold: threshold, now: now)
        } else {
            return applyActivityFilter(threads: threads, messages: messages, threshold: threshold, now: now)
        }
    }

    /// Apply activity filter (1h, 4h, 1d)
    private func applyActivityFilter(
        threads: [ThreadSummary],
        messages: [NDKEvent],
        threshold: TimeInterval,
        now: TimeInterval
    ) -> [ThreadSummary] {
        // Build map of threadID -> lastReplyTime
        var threadLastReplyMap: [String: Timestamp] = [:]

        for message in messages {
            if let threadID = message.tags(withName: "E").first?[safe: 1] {
                let createdAt = message.createdAt
                let currentLast = threadLastReplyMap[threadID] ?? 0
                if createdAt > currentLast {
                    threadLastReplyMap[threadID] = createdAt
                }
            }
        }

        return threads.filter { thread in
            let lastReplyTime = threadLastReplyMap[thread.id]

            if let lastReplyTime {
                let timeSinceLastReply = now - TimeInterval(lastReplyTime)
                return timeSinceLastReply <= threshold
            }

            let timeSinceCreation = now - thread.createdAt.timeIntervalSince1970
            return timeSinceCreation <= threshold
        }
    }

    /// Apply needs-response filter
    private func applyNeedsResponseFilter(
        threads: [ThreadSummary],
        messages: [NDKEvent],
        threshold: TimeInterval,
        now: TimeInterval
    ) -> [ThreadSummary] {
        guard let userPubkey = currentUserPubkey else {
            return threads
        }

        var threadLastOtherReplyMap: [String: Timestamp] = [:]
        var threadLastUserReplyMap: [String: Timestamp] = [:]

        for message in messages {
            guard let threadID = message.tags(withName: "E").first?[safe: 1] else {
                continue
            }
            let createdAt = message.createdAt

            if message.pubkey == userPubkey {
                let currentLast = threadLastUserReplyMap[threadID] ?? 0
                if createdAt > currentLast {
                    threadLastUserReplyMap[threadID] = createdAt
                }
            } else {
                let currentLast = threadLastOtherReplyMap[threadID] ?? 0
                if createdAt > currentLast {
                    threadLastOtherReplyMap[threadID] = createdAt
                }
            }
        }

        return threads.filter { thread in
            let lastOtherReplyTime = threadLastOtherReplyMap[thread.id]
            let lastUserReplyTime = threadLastUserReplyMap[thread.id]

            if let lastOtherReplyTime {
                if let lastUserReplyTime, lastUserReplyTime > lastOtherReplyTime {
                    return false
                }

                let timeSinceLastOtherReply = now - TimeInterval(lastOtherReplyTime)
                if timeSinceLastOtherReply < threshold {
                    return false
                }

                return true
            }

            return false
        }
    }
}
