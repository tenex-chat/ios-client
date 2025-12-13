//
// MockNDK.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation
import NDKSwiftCore
@testable import TENEXCore

/// Mock NDK for testing subscriptions and publishing
@MainActor
public final class MockNDK: NDKSubscribing, NDKPublishing, @unchecked Sendable {
    // MARK: Lifecycle

    /// Initialize a new mock NDK instance
    public init() {
        mockEvents = []
        publishedEvents = []
        // Create a minimal NDK instance just for building events
        helperNDK = NDK(relayURLs: [])
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

    /// Publish an event using the builder pattern
    /// Note: For testing, we create a simplified event since NDKEventBuilder.build() requires a signer
    @discardableResult
    public func publish(
        _ builder: @Sendable (NDKEventBuilder) -> NDKEventBuilder
    ) async throws -> (event: NDKEvent, relays: Set<NDKRelay>) {
        if publishDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(publishDelay * 1_000_000_000))
        }

        if publishShouldFail {
            throw MockError.publishFailed
        }

        // Create event from builder - extract tags and content via the builder's public properties
        let eventBuilder = builder(NDKEventBuilder(ndk: helperNDK))

        // Create a mock event directly (since builder.build() requires a signer)
        let event = NDKEvent(
            kind: eventBuilder.kind,
            content: eventBuilder.content,
            tags: eventBuilder.tags,
            pubkey: "test-user",
            createdAt: Timestamp(Date().timeIntervalSince1970)
        )

        publishedEvents.append(event)

        return (event: event, relays: [])
    }

    /// Publish a reply to an event
    /// Note: For testing, we create a simplified reply event
    @discardableResult
    public func publishReply(
        to parentEvent: NDKEvent,
        configure: @Sendable (NDKEventBuilder) -> NDKEventBuilder
    ) async throws -> (event: NDKEvent, relays: Set<NDKRelay>) {
        if publishDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(publishDelay * 1_000_000_000))
        }

        if publishShouldFail {
            throw MockError.publishFailed
        }

        // Create reply builder (simulate NDKEventBuilder.reply behavior)
        let replyBuilder = NDKEventBuilder(ndk: helperNDK)
            .kind(1111) // Generic reply

        // Add reference to parent event
        _ = replyBuilder.tag(["e", parentEvent.id])
        _ = replyBuilder.tag(["k", String(parentEvent.kind)])
        _ = replyBuilder.tag(["p", parentEvent.pubkey])

        // Apply user configuration
        let configuredBuilder = configure(replyBuilder)

        // Create the reply event directly (since builder.build() requires a signer)
        let replyEvent = NDKEvent(
            kind: configuredBuilder.kind,
            content: configuredBuilder.content,
            tags: configuredBuilder.tags,
            pubkey: "test-user",
            createdAt: Timestamp(Date().timeIntervalSince1970)
        )

        publishedEvents.append(replyEvent)

        return (event: replyEvent, relays: [])
    }

    // MARK: Private

    /// Helper NDK used for creating event builders
    private let helperNDK: NDK
}
