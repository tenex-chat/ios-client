//
// MockNDK.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation
@preconcurrency import NDKSwift
@testable import TENEXFeatures

/// Mock NDK for testing subscriptions
@MainActor
public final class MockNDK: NDKSubscribing, @unchecked Sendable {
    // MARK: Lifecycle

    /// Initialize a new mock NDK instance
    public init() {
        mockEvents = []
    }

    // MARK: Public

    // MARK: - Mock Error

    public enum MockError: Error {
        case genericError
        case connectionFailed
        case subscriptionFailed
    }

    /// Events to return from subscriptions
    public var mockEvents: [NDKEvent] = []

    /// Whether subscriptions should throw an error
    public var shouldThrowError = false

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
}
