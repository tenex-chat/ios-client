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
    public init(ndk: NDK, projectID: String) {
        self.ndk = ndk
        self.projectID = projectID
    }

    // MARK: Public

    /// The list of threads
    public private(set) var threads: [NostrThread] = []

    /// Map of thread ID to original NDKEvent (needed for ChatView navigation)
    public private(set) var threadEvents: [String: NDKEvent] = [:]

    /// Whether threads are currently being loaded
    public private(set) var isLoading = false

    /// The current error message, if any
    public private(set) var errorMessage: String?

    /// Load threads from Nostr
    public func loadThreads() async {
        // Clear error
        errorMessage = nil

        // Start loading
        isLoading = true

        defer {
            // Always stop loading when done
            isLoading = false
        }

        do {
            try await subscribeAndProcessEvents()
        } catch {
            // Set error message
            errorMessage = "Failed to load threads. Please try again."
        }
    }

    /// Refresh the thread list
    public func refresh() async {
        // Cancel existing subscription
        cancelSubscription()
        // Clear seen events for fresh subscription
        seenEventIDs.removeAll()
        // Reload threads
        await loadThreads()
    }

    /// Cancel the active subscription
    public func cancelSubscription() {
        subscriptionTask?.cancel()
        subscriptionTask = nil
    }

    // MARK: Private

    private let ndk: NDK
    private let projectID: String
    private var subscriptionTask: Task<Void, Never>?
    private var seenEventIDs: Set<String> = []

    // MARK: - Private Helpers

    /// Subscribe to thread events and process them as they arrive
    private func subscribeAndProcessEvents() async throws {
        NSLog("[ThreadListVM] ProjectID being queried: '\(projectID)'")
        let filters = createSubscriptionFilters()
        NSLog("[ThreadListVM] Starting subscription with filters: \(filters)")
        let subscription = ndk.subscribeToEvents(filters: filters)

        // State for building threads
        var threadsByID: [String: NostrThread] = [:]
        var threadEventsByID: [String: NDKEvent] = [:]
        var metadataByThreadID: [String: ConversationMetadata] = [:]
        var replyCountsByThreadID: [String: Int] = [:]

        for try await event in subscription {
            NSLog("[ThreadListVM] Received event: kind=\(event.kind) id=\(event.id)")

            // Deduplicate events by ID
            guard !seenEventIDs.contains(event.id) else {
                NSLog("[ThreadListVM] Skipping duplicate event: \(event.id)")
                continue
            }
            seenEventIDs.insert(event.id)

            // Process event and update state
            processEvent(
                event,
                threadsByID: &threadsByID,
                threadEventsByID: &threadEventsByID,
                metadataByThreadID: &metadataByThreadID,
                replyCountsByThreadID: &replyCountsByThreadID
            )

            // Update UI with current state
            updateThreads(
                threadsByID: threadsByID,
                threadEventsByID: threadEventsByID,
                metadataByThreadID: metadataByThreadID,
                replyCountsByThreadID: replyCountsByThreadID
            )
        }
    }

    /// Create subscription filters for threads, metadata, and messages
    private func createSubscriptionFilters() -> [NDKFilter] {
        let threadFilter = NostrThread.filter(for: projectID)
        let metadataFilter = NDKFilter(kinds: [513])
        let messagesFilter = NDKFilter(
            kinds: [1111],
            tags: ["a": Set([projectID])]
        )
        return [threadFilter, metadataFilter, messagesFilter]
    }

    /// Process an individual event and update state dictionaries
    private func processEvent(
        _ event: NDKEvent,
        threadsByID: inout [String: NostrThread],
        threadEventsByID: inout [String: NDKEvent],
        metadataByThreadID: inout [String: ConversationMetadata],
        replyCountsByThreadID: inout [String: Int]
    ) {
        switch event.kind {
        case 11:
            NSLog("[ThreadListVM] Processing kind:11 thread event")
            if let thread = NostrThread.from(event: event) {
                NSLog("[ThreadListVM] Successfully parsed thread: id=\(thread.id) title=\(thread.title)")
                threadsByID[thread.id] = thread
                threadEventsByID[thread.id] = event // Store original event for navigation
            } else {
                NSLog("[ThreadListVM] Failed to parse thread from event: \(event.id)")
            }

        case 513:
            if let metadata = ConversationMetadata.from(event: event) {
                // Only use metadata if it's newer than what we already have
                if let existing = metadataByThreadID[metadata.threadID] {
                    guard metadata.createdAt > existing.createdAt else {
                        return
                    }
                }
                metadataByThreadID[metadata.threadID] = metadata
            }

        case 1111:
            // Messages reference their thread root via uppercase "E" tag (NIP-22)
            if let threadID = event.tags(withName: "E").first?[safe: 1] {
                replyCountsByThreadID[threadID, default: 0] += 1
            }

        default:
            break
        }
    }

    /// Update the threads array by merging data from kind:11, kind:513, and kind:1111
    private func updateThreads(
        threadsByID: [String: NostrThread],
        threadEventsByID: [String: NDKEvent],
        metadataByThreadID: [String: ConversationMetadata],
        replyCountsByThreadID: [String: Int]
    ) {
        NSLog("[ThreadListVM] updateThreads called with \(threadsByID.count) threads")

        // Build enriched threads
        var enrichedThreads: [NostrThread] = []

        for (threadID, thread) in threadsByID {
            // Get metadata if available
            let metadata = metadataByThreadID[threadID]

            // Get reply count if available
            let replyCount = replyCountsByThreadID[threadID] ?? 0

            // Create enriched thread
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

        // Sort by creation date (newest first)
        threads = enrichedThreads.sorted { $0.createdAt > $1.createdAt }
        // Store thread events for navigation
        threadEvents = threadEventsByID
        NSLog("[ThreadListVM] Final threads array count: \(threads.count)")
    }
}
