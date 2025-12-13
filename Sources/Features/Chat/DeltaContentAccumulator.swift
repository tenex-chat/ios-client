//
// DeltaContentAccumulator.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation
import Observation

// MARK: - DeltaContentAccumulator

/// Accumulates streaming deltas with sequence-based ordering.
///
/// Handles out-of-order delta delivery over Nostr relays by using sequence
/// numbers to reconstruct the correct content order.
///
/// Per STREAMING.md:
/// - Fast path: If sequence is next expected, just append (O(1))
/// - Slow path: Out-of-order detected, full reconstruction from all deltas
@MainActor
@Observable
public final class DeltaContentAccumulator {
    // MARK: Lifecycle

    /// Creates a new empty accumulator.
    public init() {}

    // MARK: Public

    /// The reconstructed content from all accumulated deltas
    public private(set) var content = ""

    /// Add a delta and return the reconstructed content.
    /// - Parameters:
    ///   - sequence: The sequence number for ordering
    ///   - content: The delta content to add
    /// - Returns: The fully reconstructed content
    @discardableResult
    public func addDelta(sequence: Int, content deltaContent: String) -> String {
        // Store the delta
        deltas[sequence] = deltaContent

        // Always reconstruct to handle out-of-order delivery correctly.
        // The fast path optimization was buggy when transitioning from
        // slow path (out-of-order) back to fast path (in-order).
        // Simple reconstruction is correct and performant for typical message sizes.
        content = reconstruct()

        return content
    }

    /// Clear all accumulated deltas and reset state.
    public func clear() {
        deltas.removeAll()
        content = ""
    }

    // MARK: Private

    /// Stored deltas by sequence number
    private var deltas: [Int: String] = [:]

    /// Reconstruct content from all deltas in sequence order
    private func reconstruct() -> String {
        deltas.keys.sorted().compactMap { deltas[$0] }.joined()
    }
}
