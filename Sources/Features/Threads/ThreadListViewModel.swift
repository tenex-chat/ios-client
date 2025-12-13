//
// ThreadListViewModel.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation
import NDKSwiftCoreCore
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
        self.projectID = projectID
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
            // Subscribe to kind:11 (Thread) events for this project
            let threadFilter = NostrThread.filter(for: projectID)
            let subscription = ndk.subscribeToEvents(filters: [threadFilter])

            var loadedThreads: [NostrThread] = []

            for try await event in subscription {
                // Parse as Thread
                if let thread = NostrThread.from(event: event) {
                    loadedThreads.append(thread)
                    // Update UI immediately as threads arrive
                    threads = loadedThreads.sorted { $0.createdAt > $1.createdAt }
                }
            }

            // Subscription finished (after EOSE)
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
}
