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

    /// Kind 24111: Typing indicator start
    static let kindTypingStart: UInt32 = 24_111

    /// Kind 24112: Typing indicator stop
    static let kindTypingStop: UInt32 = 24_112

    // MARK: - Event Type Detection

    /// Whether this is a streaming delta event (kind 21111)
    var isStreamingDelta: Bool {
        kind == Self.kindStreamingDelta
    }

    /// Whether this is a final message event (kind 1111)
    var isFinalMessage: Bool {
        kind == Self.kindGenericReply
    }

    /// Whether this is a typing start indicator (kind 24111)
    var isTypingStart: Bool {
        kind == Self.kindTypingStart
    }

    /// Whether this is a typing stop indicator (kind 24112)
    var isTypingStop: Bool {
        kind == Self.kindTypingStop
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
