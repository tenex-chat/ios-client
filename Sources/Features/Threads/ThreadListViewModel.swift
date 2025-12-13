//
// ThreadListViewModel.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation
import NDKSwiftCore
import Observation
import TENEXCore

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
    public init(ndk: any NDKSubscribing, projectID: String) {
        self.ndk = ndk
        projectID = projectID
    }

    // MARK: Public

    /// The list of threads
    public private(set) var threads: [NostrThread] = []

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
        await loadThreads()
    }

    // MARK: Private

    private let ndk: any NDKSubscribing
    private let projectID: String

    // MARK: - Private Helpers

    /// Subscribe to thread events and process them as they arrive
    private func subscribeAndProcessEvents() async throws {
        // Subscribe to three kinds:
        // 1. kind:11 - Thread events
        // 2. kind:513 - Conversation metadata (title/summary)
        // 3. kind:1111 - Messages (for reply counting)

        let threadFilter = NostrThread.filter(for: projectID)
        let metadataFilter = NDKFilter(kinds: [513]) // All metadata, we'll filter by thread
        let messagesFilter = NDKFilter(
            kinds: [1111], // swiftlint:disable:this number_separator
            tags: ["a": [projectID]]
        )

        let subscription = ndk.subscribeToEvents(filters: [threadFilter, metadataFilter, messagesFilter])

        // State for building threads
        var threadsByID: [String: NostrThread] = [:]
        var metadataByThreadID: [String: ConversationMetadata] = [:]
        var replyCountsByThreadID: [String: Int] = [:]

        for try await event in subscription {
            switch event.kind {
            case 11:
                // Parse as Thread
                if let thread = NostrThread.from(event: event) {
                    threadsByID[thread.id] = thread
                    updateThreads(
                        threadsByID: threadsByID,
                        metadataByThreadID: metadataByThreadID,
                        replyCountsByThreadID: replyCountsByThreadID
                    )
                }

            case 513:
                // Parse as ConversationMetadata
                if let metadata = ConversationMetadata.from(event: event) {
                    metadataByThreadID[metadata.threadID] = metadata
                    updateThreads(
                        threadsByID: threadsByID,
                        metadataByThreadID: metadataByThreadID,
                        replyCountsByThreadID: replyCountsByThreadID
                    )
                }

            case 1111: // swiftlint:disable:this number_separator
                // Count replies with uppercase "E" tag
                if let threadID = event.tags(withName: "E").first?[safe: 1] {
                    replyCountsByThreadID[threadID, default: 0] += 1
                    updateThreads(
                        threadsByID: threadsByID,
                        metadataByThreadID: metadataByThreadID,
                        replyCountsByThreadID: replyCountsByThreadID
                    )
                }

            default:
                break
            }
        }
    }

    /// Update the threads array by merging data from kind:11, kind:513, and kind:1111
    private func updateThreads(
        threadsByID: [String: NostrThread],
        metadataByThreadID: [String: ConversationMetadata],
        replyCountsByThreadID: [String: Int]
    ) {
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
    }
}

// MARK: - Safe Array Access

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
