//
// ThreadListViewModel.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation
import NDKSwiftCore
import Observation
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
    ///   - projectId: The project addressable coordinate (kind:pubkey:dTag)
    ///   - archiveStorage: Storage for archived thread IDs
    public init(
        ndk: NDK,
        projectID: String,
        archiveStorage: ThreadArchiveStorage = UserDefaultsThreadArchiveStorage()
    ) {
        self.ndk = ndk
        self.projectID = projectID
        self.archiveStorage = archiveStorage
    }

    // MARK: Public

    /// Map of thread ID to original NDKEvent (needed for ChatView navigation)
    public private(set) var threadEvents: [String: NDKEvent] = [:]

    /// The list of threads, enriched with metadata and reply counts
    public var threads: [NostrThread] {
        let threadEvents = threadEventsSubscription?.data ?? []
        let metadataEvents = metadataSubscription?.data ?? []
        let messageEvents = messagesSubscription?.data ?? []

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
        let nonArchivedThreads = filterArchivedThreads(from: enrichedThreads)

        // Sort by creation date (newest first)
        return nonArchivedThreads.sorted { $0.createdAt > $1.createdAt }
    }

    /// The current error message, if any
    public var errorMessage: String? {
        threadEventsSubscription?.error?.localizedDescription ??
            metadataSubscription?.error?.localizedDescription ??
            messagesSubscription?.error?.localizedDescription
    }

    /// Subscribe to all thread-related events
    public func subscribe() {
        // Subscribe to thread events (kind:11)
        let threadFilter = NostrThread.filter(for: projectID)
        threadEventsSubscription = ndk.subscribe(filter: threadFilter)

        // Subscribe to metadata events (kind:513)
        let metadataFilter = NDKFilter(kinds: [513])
        metadataSubscription = ndk.subscribe(filter: metadataFilter)

        // Subscribe to message events (kind:1111)
        let messagesFilter = NDKFilter(
            kinds: [1111],
            tags: ["a": Set([projectID])]
        )
        messagesSubscription = ndk.subscribe(filter: messagesFilter)
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

    // MARK: Internal

    private(set) var threadEventsSubscription: NDKSubscription<NDKEvent>?
    private(set) var metadataSubscription: NDKSubscription<NDKEvent>?
    private(set) var messagesSubscription: NDKSubscription<NDKEvent>?

    // MARK: Private

    private let ndk: NDK
    private let projectID: String
    private let archiveStorage: ThreadArchiveStorage

    /// Filter out archived threads
    private func filterArchivedThreads(from threads: [NostrThread]) -> [NostrThread] {
        let archivedIDs = archiveStorage.archivedThreadIDs()
        return threads.filter { !archivedIDs.contains($0.id) }
    }
}
