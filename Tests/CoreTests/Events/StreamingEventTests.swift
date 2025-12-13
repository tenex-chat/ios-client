//
// StreamingEventTests.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation
import NDKSwiftCore
import NDKSwiftTesting
import TENEXCore
import Testing

@Suite("Streaming Event Tests")
struct StreamingEventTests {
    @Test("Parse valid kind:21111 event into StreamingDelta model")
    func parseValidStreamingEvent() throws {
        // Given: A valid kind:21111 event
        let pubkey = "npub1testpubkey1234567890abcdef"
        let messageID = "message-id-456"
        let delta = "This is a chunk of text"
        let createdAt = Timestamp(Date().timeIntervalSince1970)

        let event = NDKEvent.test(
            kind: 21_111,
            content: delta,
            tags: [
                ["e", messageID],
            ],
            pubkey: pubkey,
            createdAt: createdAt
        )

        // When: Converting event to StreamingDelta
        let streamingDelta = try #require(StreamingDelta.from(event: event))

        // Then: StreamingDelta properties match event data
        // Note: event.id is empty for unsigned test events (ID is computed from signature)
        #expect(streamingDelta.pubkey == pubkey)
        #expect(streamingDelta.messageID == messageID)
        #expect(streamingDelta.delta == delta)
        #expect(streamingDelta.createdAt.timeIntervalSince1970 == TimeInterval(createdAt))
    }

    @Test("Extract message ID from e tag")
    func extractMessageID() throws {
        // Given: Event with message reference in e tag
        let messageID = "target-message-id"
        let event = NDKEvent.test(
            kind: 21_111,
            content: "delta chunk",
            tags: [
                ["e", messageID],
            ],
            pubkey: "testpubkey"
        )

        // When: Converting to StreamingDelta
        let delta = try #require(StreamingDelta.from(event: event))

        // Then: Message ID is extracted
        #expect(delta.messageID == messageID)
    }

    @Test("Handle empty delta content")
    func handleEmptyDeltaContent() throws {
        // Given: Event with empty content
        let event = NDKEvent.test(
            kind: 21_111,
            content: "",
            tags: [
                ["e", "message-id"],
            ],
            pubkey: "testpubkey"
        )

        // When: Converting to StreamingDelta
        let delta = try #require(StreamingDelta.from(event: event))

        // Then: Delta is empty string
        #expect(delta.delta.isEmpty)
    }

    @Test("Return nil for missing e tag")
    func returnNilForMissingETag() {
        // Given: Event without e tag (message reference)
        let event = NDKEvent.test(
            kind: 21_111,
            content: "delta",
            tags: [],
            pubkey: "testpubkey"
        )

        // When: Converting to StreamingDelta
        let delta = StreamingDelta.from(event: event)

        // Then: Returns nil
        #expect(delta == nil)
    }

    @Test("Return nil for empty e tag value")
    func returnNilForEmptyETag() {
        // Given: Event with empty e tag value
        let event = NDKEvent.test(
            kind: 21_111,
            content: "delta",
            tags: [
                ["e", ""],
            ],
            pubkey: "testpubkey"
        )

        // When: Converting to StreamingDelta
        let delta = StreamingDelta.from(event: event)

        // Then: Returns nil
        #expect(delta == nil)
    }

    @Test("Return nil for wrong kind")
    func returnNilForWrongKind() {
        // Given: Event with wrong kind
        let event = NDKEvent.test(
            kind: 1111, // Wrong kind (should be 21111)
            content: "delta",
            tags: [
                ["e", "message-id"],
            ],
            pubkey: "testpubkey"
        )

        // When: Converting to StreamingDelta
        let delta = StreamingDelta.from(event: event)

        // Then: Returns nil
        #expect(delta == nil)
    }

    @Test("Create filter for fetching deltas by message")
    func createFilterForDeltas() {
        // Given: A message ID
        let messageID = "message-123"

        // When: Creating filter for streaming deltas
        let filter = StreamingDelta.filter(for: messageID)

        // Then: Filter has correct parameters
        #expect(filter.kinds == [21_111])
        #expect(filter.tags?["e"] == [messageID])
    }
}
