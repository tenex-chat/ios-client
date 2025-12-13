//
// MockNDK.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation
import NDKSwiftCoreCore
@testable import TENEXFeatures

/// Mock NDK for testing subscriptions and publishing
@MainActor
public final class MockNDK: NDKSubscribing, NDKPublishing, @unchecked Sendable {
    // MARK: Lifecycle

    /// Initialize a new mock NDK instance
    public init() {
        mockEvents = []
        publishedEvents = []
    }

    // MARK: Public

    // MARK: - Mock Error

    public enum MockError: Error {
        case genericError
        case connectionFailed
        case subscriptionFailed
        case publishFailed
    }

    /// Events to return from subscriptions
    public var mockEvents: [NDKEvent] = []

    /// Events that have been published
    public var publishedEvents: [NDKEvent] = []

    /// Whether subscriptions should throw an error
    public var shouldThrowError = false

    /// Whether publishing should fail
    public var publishShouldFail = false

    /// Delay before publish completes (for testing async behavior)
    public var publishDelay: TimeInterval = 0

    /// Error to throw if shouldThrowError is true
    public var errorToThrow: Error = MockError.genericError

    /// Create a mock subscription that returns the mock events
    public func subscribeToEvents(filters _: [NDKFilter]) -> AsyncThrowingStream<NDKEvent, Error> {
        let events = mockEvents
        let shouldError = shouldThrowError
        let error = errorToThrow
        return AsyncThrowingStream { continuation in
            if shouldError {
                continuation.finish(throwing: error)
            } else {
                for event in events {
                    continuation.yield(event)
                }
                continuation.finish()
            }
        }
    }

    /// Publish an event
    public func publish(_ event: NDKEvent) async throws {
        if publishDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(publishDelay * 1_000_000_000))
        }

        if publishShouldFail {
            throw MockError.publishFailed
        }

        // Generate event ID if not present (simulate signing)
        if event.id == nil || event.id?.isEmpty == true {
            event.id = UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
        }

        publishedEvents.append(event)
    }
}
