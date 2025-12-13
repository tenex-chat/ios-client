//
// NDKProtocols.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation
import NDKSwiftCore

// MARK: - NDKProtocols

/// Namespace for NDK extensions
public enum NDKProtocols {}

// MARK: - NDKSubscribing

/// Protocol for subscribing to Nostr events
public protocol NDKSubscribing: AnyObject {
    /// Subscribe to events matching the given filters
    /// - Parameter filters: The filters to apply
    /// - Returns: An async throwing stream of events
    @MainActor
    func subscribeToEvents(filters: [NDKFilter]) -> AsyncThrowingStream<NDKEvent, Error>
}

// MARK: - NDKPublishing

/// Protocol for publishing Nostr events
public protocol NDKPublishing: AnyObject {
    /// Publish an event using the builder pattern
    /// - Parameter builder: A closure that configures the event builder
    /// - Returns: The published event and the relays that accepted it
    @MainActor
    @discardableResult
    func publish(
        _ builder: @Sendable (NDKEventBuilder) -> NDKEventBuilder
    ) async throws -> (event: NDKEvent, relays: Set<NDKRelay>)

    /// Publish a reply to an event (NIP-22 compliant)
    /// - Parameters:
    ///   - event: The event to reply to
    ///   - configure: A closure to configure the reply builder
    /// - Returns: The published event and the relays that accepted it
    @MainActor
    @discardableResult
    func publishReply(
        to event: NDKEvent,
        configure: @Sendable (NDKEventBuilder) -> NDKEventBuilder
    ) async throws -> (event: NDKEvent, relays: Set<NDKRelay>)
}

// MARK: - NDK + NDKSubscribing

extension NDK: NDKSubscribing {}

// MARK: - NDK + NDKPublishing

extension NDK: NDKPublishing {}

// MARK: - NDK Extensions

public extension NDK {
    /// Subscribe to Nostr events matching multiple filters, merging results into a single stream
    /// - Parameter filters: The filters to apply (each filter creates a subscription)
    /// - Returns: An async throwing stream of events from all subscriptions
    @MainActor
    func subscribeToEvents(filters: [NDKFilter]) -> AsyncThrowingStream<NDKEvent, Error> {
        let subscriptions = filters.map { subscribe(filter: $0) }

        return AsyncThrowingStream { continuation in
            let task = Task {
                await withTaskGroup(of: Void.self) { group in
                    for subscription in subscriptions {
                        group.addTask {
                            for await event in subscription.events {
                                continuation.yield(event)
                            }
                        }
                    }
                    await group.waitForAll()
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    /// Publish a reply to an event using NDKEventBuilder.reply (NIP-22 compliant)
    /// - Parameters:
    ///   - event: The event to reply to (e.g., a thread event)
    ///   - configure: A closure to configure the reply builder
    /// - Returns: The published event and the relays that accepted it
    /// - Throws: An error if publishing fails
    @discardableResult
    func publishReply(
        to event: NDKEvent,
        configure: @Sendable (NDKEventBuilder) -> NDKEventBuilder
    ) async throws -> (event: NDKEvent, relays: Set<NDKRelay>) {
        try await publish { _ in
            configure(NDKEventBuilder.reply(to: event, ndk: self))
        }
    }
}
