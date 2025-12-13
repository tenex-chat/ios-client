//
// StreamingSession.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation
import NDKSwiftCore

// MARK: - StreamingSession

/// Tracks an active streaming response from an agent.
///
/// Keyed by pubkey (not message ID) since we only expect one active
/// streaming response per agent at a time.
@MainActor
public struct StreamingSession {
    // MARK: Lifecycle

    /// Creates a new streaming session from the first delta event.
    /// - Parameter event: The first streaming delta event (kind 21111)
    public init(event: NDKEvent) {
        syntheticID = UUID().uuidString
        accumulator = DeltaContentAccumulator()
        latestEvent = event

        // Extract sequence number and add initial delta
        let sequence = event.sequenceNumber ?? 0
        accumulator.addDelta(sequence: sequence, content: event.content)
    }

    // MARK: Public

    /// Unique ID for this streaming session (used for synthetic message display)
    public let syntheticID: String

    /// The most recent event received in this streaming session
    public private(set) var latestEvent: NDKEvent

    /// The reconstructed content from all accumulated deltas
    public var reconstructedContent: String {
        accumulator.content
    }

    /// Add a delta from a streaming event.
    /// - Parameter event: The streaming delta event (kind 21111)
    public mutating func addDelta(from event: NDKEvent) {
        latestEvent = event
        let sequence = event.sequenceNumber ?? 0
        accumulator.addDelta(sequence: sequence, content: event.content)
    }

    // MARK: Private

    private var accumulator: DeltaContentAccumulator
}
