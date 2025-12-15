//
// NDKEvent+Streaming.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation
import NDKSwiftCore

// MARK: - NDKEvent Streaming Extensions

public extension NDKEvent {
    // MARK: - Event Kinds

    /// Kind 1111: Generic reply / final message
    static let kindGenericReply: UInt32 = 1111

    /// Kind 21111: Streaming delta
    static let kindStreamingDelta: UInt32 = 21_111

    // MARK: - Event Type Detection

    /// Whether this is a streaming delta event (kind 21111)
    var isStreamingDelta: Bool {
        kind == Self.kindStreamingDelta
    }

    /// Whether this is a final message event (kind 1111)
    var isFinalMessage: Bool {
        kind == Self.kindGenericReply
    }

    // MARK: - Sequence Number

    /// The sequence number from the ["sequence", "N"] tag, or nil if not present
    var sequenceNumber: Int? {
        for tag in tags where tag.first == "sequence" {
            if let sequenceStr = tag[safe: 1], let sequence = Int(sequenceStr) {
                return sequence
            }
        }
        return nil
    }
}
