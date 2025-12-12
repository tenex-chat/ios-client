//
// ProjectListViewModel.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation
@preconcurrency import NDKSwift
import Observation
import TENEXCore

// MARK: - NDKSubscribing

/// Protocol for objects that can subscribe to Nostr events
public protocol NDKSubscribing: Sendable {
    /// Subscribe to Nostr events matching the given filters
    /// - Parameter filters: The filters to apply
    /// - Returns: An async throwing stream of events
    @MainActor func subscribeToEvents(filters: [NDKFilter]) -> AsyncThrowingStream<NDKEvent, Error>
}

// MARK: - NDK + NDKSubscribing

/// Extend NDK to conform to the protocol
extension NDK: NDKSubscribing {
    @MainActor
    public func subscribeToEvents(filters: [NDKFilter]) -> AsyncThrowingStream<NDKEvent, Error> {
        let subscription = subscribe(filters: filters)
        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    for try await event in subscription {
                        continuation.yield(event)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
}

// MARK: - ProjectListViewModel

/// View model for the project list screen
@MainActor
@Observable
public final class ProjectListViewModel {
    // MARK: Lifecycle

    /// Initialize the project list view model
    /// - Parameters:
    ///   - ndk: The NDK instance for fetching projects
    ///   - userPubkey: The pubkey of the authenticated user
    public init(ndk: any NDKSubscribing, userPubkey: String) {
        self.ndk = ndk
        self.userPubkey = userPubkey
    }

    // MARK: Public

    /// The list of projects
    public private(set) var projects: [Project] = []

    /// Whether projects are currently being loaded
    public private(set) var isLoading = false

    /// The current error message, if any
    public private(set) var errorMessage: String?

    /// Load projects from Nostr
    public func loadProjects() async {
        // Clear error
        errorMessage = nil

        // Start loading
        isLoading = true

        defer {
            // Always stop loading when done
            isLoading = false
        }

        do {
            // Create filter for projects by this user
            let filter = Project.filter(for: userPubkey)

            // Subscribe to projects
            var fetchedProjects: [Project] = []

            let subscription = ndk.subscribeToEvents(filters: [filter])

            for try await event in subscription {
                // Try to parse as Project
                if let project = Project.from(event: event) {
                    fetchedProjects.append(project)
                }
            }

            // Update projects list
            projects = fetchedProjects
        } catch {
            // Set error message
            errorMessage = "Failed to load projects. Please try again."
        }
    }

    /// Refresh the project list
    public func refresh() async {
        await loadProjects()
    }

    // MARK: Private

    private let ndk: any NDKSubscribing
    private let userPubkey: String
}
