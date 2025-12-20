//
// FeedService.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation
import NDKSwiftCore

// MARK: - FeedServiceError

/// Errors that can occur in the feed service
public enum FeedServiceError: Error, LocalizedError {
    case subscriptionFailed
    case invalidProjectID
    case ndkNotAvailable

    public var errorDescription: String? {
        switch self {
        case .subscriptionFailed:
            return "Failed to subscribe to feed events"
        case .invalidProjectID:
            return "Invalid project identifier"
        case .ndkNotAvailable:
            return "Network service is not available"
        }
    }
}

// MARK: - FeedServiceProtocol

/// Protocol defining the feed service interface
@MainActor
public protocol FeedServiceProtocol {
    /// Subscribe to events for a specific project
    /// - Parameter projectID: The project identifier
    /// - Returns: A subscription to project events
    /// - Throws: FeedServiceError if subscription fails
    func subscribeToProject(_ projectID: String) async throws -> NDKSubscription<NDKEvent>

    /// Unsubscribe from current feed
    func unsubscribe()
}

// MARK: - FeedService

/// Service responsible for managing feed data from Nostr network
@MainActor
public final class FeedService: FeedServiceProtocol {
    // MARK: Lifecycle

    /// Initialize the feed service
    /// - Parameter ndk: The NDK instance for network operations
    public init(ndk: NDK) {
        self.ndk = ndk
    }

    // MARK: Public

    /// Subscribe to events for a specific project
    public func subscribeToProject(_ projectID: String) async throws -> NDKSubscription<NDKEvent> {
        guard !projectID.isEmpty else {
            throw FeedServiceError.invalidProjectID
        }

        // Clean up any existing subscription
        unsubscribe()

        // Create filter for project events
        let filter = NDKFilter(tags: ["a": [projectID]])

        // Create subscription
        let subscription = ndk.subscribe(filter: filter)
        currentSubscription = subscription

        return subscription
    }

    /// Unsubscribe from current feed
    public func unsubscribe() {
        currentSubscription = nil
    }

    // MARK: Private

    private let ndk: NDK
    private var currentSubscription: NDKSubscription<NDKEvent>?
}

// MARK: - MockFeedService

/// Mock implementation of FeedService for testing and previews
@MainActor
public final class MockFeedService: FeedServiceProtocol {
    // MARK: Public

    public var shouldFail = false
    public var mockEvents: [NDKEvent] = []
    public private(set) var subscribeCallCount = 0
    public private(set) var unsubscribeCallCount = 0

    public init() {}

    public func subscribeToProject(_ projectID: String) async throws -> NDKSubscription<NDKEvent> {
        subscribeCallCount += 1

        if shouldFail {
            throw FeedServiceError.subscriptionFailed
        }

        // Return a mock subscription (this won't work in practice but is useful for testing)
        guard let ndk = try? NDK() else {
            throw FeedServiceError.ndkNotAvailable
        }
        let filter = NDKFilter(tags: ["a": [projectID]])
        return ndk.subscribe(filter: filter)
    }

    public func unsubscribe() {
        unsubscribeCallCount += 1
    }
}
