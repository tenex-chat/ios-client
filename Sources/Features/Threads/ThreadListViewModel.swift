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

/// Typealias for TENEXCore.Thread to avoid conflict with Foundation.Thread
public typealias NostrThread = TENEXCore.Thread

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
    }

    // MARK: Public

    /// Map of thread ID to original NDKEvent (needed for ChatView navigation)
    public private(set) var threadEvents: [String: NDKEvent] = [:]

    /// The list of threads, enriched with metadata and reply counts
    public var threads: [NostrThread] {
        let threadEvents = self.threadEventsSubscription?.data ?? []
        let metadataEvents = self.metadataSubscription?.data ?? []
        let messageEvents = self.messagesSubscription?.data ?? []

        Logger()
            .info(
                "[ThreadListViewModel] Building threads - threadEvents: \(threadEvents.count), metadataEvents: \(metadataEvents.count), messageEvents: \(messageEvents.count)"
            )

        // Build threads from kind:11 events
        var threadsByID: [String: NostrThread] = [:]
        var threadEventsByID: [String: NDKEvent] = [:]

        for event in threadEvents {
            if let thread = NostrThread.from(event: event) {
                threadsByID[thread.id] = thread
                threadEventsByID[thread.id] = event
            }
        }

        // Build metadata map from kind:513 events
        var metadataByThreadID: [String: ConversationMetadata] = [:]
        for event in metadataEvents {
            if let metadata = ConversationMetadata.from(event: event) {
                // Only use metadata if it's newer than what we already have
                if let existing = metadataByThreadID[metadata.threadID] {
                    guard metadata.createdAt > existing.createdAt else {
                        continue
                    }
                }
                metadataByThreadID[metadata.threadID] = metadata
            }
        }

        // Build reply counts from kind:1111 events
        var replyCountsByThreadID: [String: Int] = [:]
        for event in messageEvents {
            // Messages reference their thread root via uppercase "E" tag (NIP-22)
            if let threadID = event.tags(withName: "E").first?[safe: 1] {
                replyCountsByThreadID[threadID, default: 0] += 1
            }
        }

        // Merge everything into enriched threads
        var enrichedThreads: [NostrThread] = []
        for (threadID, thread) in threadsByID {
            let metadata = metadataByThreadID[threadID]
            let replyCount = replyCountsByThreadID[threadID] ?? 0

            let enrichedThread = NostrThread(
                id: thread.id,
                pubkey: thread.pubkey,
                projectID: thread.projectID,
                title: metadata?.title ?? thread.title,
                summary: metadata?.summary ?? thread.summary,
                createdAt: thread.createdAt,
                replyCount: replyCount > 0 ? replyCount : thread.replyCount,
                phase: thread.phase
            )

            enrichedThreads.append(enrichedThread)
        }

        // Store thread events for navigation
        self.threadEvents = threadEventsByID

        // Filter out archived threads
        var filteredThreads = self.filterArchivedThreads(from: enrichedThreads)

        // Apply time-based filter if one is set
        let activeFilter = self.filtersStore.getFilter(for: self.projectID)
        if let filter = activeFilter {
            filteredThreads = self.applyFilter(filter, to: filteredThreads, messages: messageEvents)
        }

        // Sort by creation date (newest first)
        return filteredThreads.sorted { $0.createdAt > $1.createdAt }
    }

    /// The current error message, if any
    public var errorMessage: String? {
        self.threadEventsSubscription?.error?.localizedDescription ??
            self.metadataSubscription?.error?.localizedDescription ??
            self.messagesSubscription?.error?.localizedDescription
    }

    /// Subscribe to all thread-related events
    public func subscribe() {
        Logger().info("[ThreadListViewModel] subscribe() called for projectID: \(self.projectID)")

        // Subscribe to thread events (kind:11)
        let threadFilter = NostrThread.filter(for: self.projectID)
        Logger().info("[ThreadListViewModel] Thread filter: kinds=[11], tags=[a:\(self.projectID)]")
        self.threadEventsSubscription = self.ndk.subscribe(filter: threadFilter)

        // Subscribe to metadata events (kind:513)
        let metadataFilter = NDKFilter(kinds: [513])
        self.metadataSubscription = self.ndk.subscribe(filter: metadataFilter)

        // Subscribe to message events (kind:1111)
        let messagesFilter = NDKFilter(
            kinds: [1111],
            tags: ["a": Set([projectID])]
        )
        self.messagesSubscription = self.ndk.subscribe(filter: messagesFilter)

        Logger().info("[ThreadListViewModel] All subscriptions created")
    }

    /// Restart all subscriptions (useful when they get stuck)
    public func restartSubscriptions() {
        // Cancel existing subscriptions
        self.threadEventsSubscription = nil
        self.metadataSubscription = nil
        self.messagesSubscription = nil

        // Resubscribe
        self.subscribe()
    }

    /// Archive a thread (hide from list)
    /// - Parameter id: The thread ID to archive
    public func archiveThread(id: String) async {
        self.archiveStorage.archive(threadID: id)
    }

    /// Unarchive a thread (restore to list)
    /// - Parameter id: The thread ID to unarchive
    public func unarchiveThread(id: String) async {
        self.archiveStorage.unarchive(threadID: id)
    }

    // MARK: Internal

    private(set) var threadEventsSubscription: NDKSubscription<NDKEvent>?
    private(set) var metadataSubscription: NDKSubscription<NDKEvent>?
    private(set) var messagesSubscription: NDKSubscription<NDKEvent>?

    // MARK: Private

    private let ndk: NDK
    private let projectID: String
    private let filtersStore: ThreadFiltersStore
    private let currentUserPubkey: String?
    private let archiveStorage: ThreadArchiveStorage

    /// Filter out archived threads
    private func filterArchivedThreads(from threads: [NostrThread]) -> [NostrThread] {
        let archivedIDs = self.archiveStorage.archivedThreadIDs()
        return threads.filter { !archivedIDs.contains($0.id) }
    }

    /// Apply the selected filter to the thread list
    /// - Parameters:
    ///   - filter: The filter to apply
    ///   - threads: The threads to filter
    ///   - messages: The message events (kind:1111)
    /// - Returns: The filtered threads
    private func applyFilter(_ filter: ThreadFilter, to threads: [NostrThread], messages: [NDKEvent]) -> [NostrThread] {
        let now = Date().timeIntervalSince1970
        let threshold = filter.thresholdSeconds

        if filter.isNeedsResponseFilter {
            // Needs-response filter: Show threads where others have replied but user hasn't responded yet
            return self.applyNeedsResponseFilter(threads: threads, messages: messages, threshold: threshold, now: now)
        } else {
            // Activity filter: Show threads with activity within the time window
            return self.applyActivityFilter(threads: threads, messages: messages, threshold: threshold, now: now)
        }
    }

    /// Apply activity filter (1h, 4h, 1d)
    private func applyActivityFilter(
        threads: [NostrThread],
        messages: [NDKEvent],
        threshold: TimeInterval,
        now: TimeInterval
    ) -> [NostrThread] {
        // Build map of threadID → lastReplyTime (from any user)
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

        // Filter threads based on last activity time
        return threads.filter { thread in
            let lastReplyTime = threadLastReplyMap[thread.id]

            // If thread has any replies
            if let lastReplyTime {
                let timeSinceLastReply = now - TimeInterval(lastReplyTime)
                // Show threads that have had a reply within the selected timeframe
                return timeSinceLastReply <= threshold
            }

            // Also include threads created within the timeframe (even if no replies yet)
            let timeSinceCreation = now - thread.createdAt.timeIntervalSince1970
            return timeSinceCreation <= threshold
        }
    }

    /// Apply needs-response filter
    private func applyNeedsResponseFilter(
        threads: [NostrThread],
        messages: [NDKEvent],
        threshold: TimeInterval,
        now: TimeInterval
    ) -> [NostrThread] {
        guard let userPubkey = currentUserPubkey else {
            // Can't filter by needs-response without knowing the current user
            return threads
        }

        // Build two maps: threadID → lastOtherReplyTime and threadID → lastUserReplyTime
        var threadLastOtherReplyMap: [String: Timestamp] = [:]
        var threadLastUserReplyMap: [String: Timestamp] = [:]

        for message in messages {
            guard let threadID = message.tags(withName: "E").first?[safe: 1] else {
                continue
            }
            let createdAt = message.createdAt

            if message.pubkey == userPubkey {
                // Track user's own replies
                let currentLast = threadLastUserReplyMap[threadID] ?? 0
                if createdAt > currentLast {
                    threadLastUserReplyMap[threadID] = createdAt
                }
            } else {
                // Track replies from others
                let currentLast = threadLastOtherReplyMap[threadID] ?? 0
                if createdAt > currentLast {
                    threadLastOtherReplyMap[threadID] = createdAt
                }
            }
        }

        // Filter threads that need a response from the current user
        return threads.filter { thread in
            let lastOtherReplyTime = threadLastOtherReplyMap[thread.id]
            let lastUserReplyTime = threadLastUserReplyMap[thread.id]

            // If someone else has replied
            if let lastOtherReplyTime {
                // Check if user has already responded after this reply
                if let lastUserReplyTime, lastUserReplyTime > lastOtherReplyTime {
                    // User has already responded, don't show
                    return false
                }

                // Check if the time since the other person's reply exceeds the threshold
                let timeSinceLastOtherReply = now - TimeInterval(lastOtherReplyTime)
                if timeSinceLastOtherReply < threshold {
                    // Reply is still within the threshold time, don't show yet
                    return false
                }

                // Someone replied more than threshold ago and user hasn't responded yet
                return true
            }

            // Don't include threads without replies from others
            return false
        }
    }
}
