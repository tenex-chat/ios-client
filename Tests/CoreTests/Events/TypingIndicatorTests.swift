//
// TypingIndicatorTests.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation
import NDKSwiftCore
import NDKSwiftTesting
import TENEXCore
import Testing

@Suite("Typing Indicator Tests")
struct TypingIndicatorTests {
    @Test("Parse valid kind:24111 event (user typing)")
    func parseUserTypingEvent() throws {
        // Given: A valid kind:24111 event (user typing)
        let pubkey = "npub1testpubkey1234567890abcdef"
        let threadID = "thread-id-456"
        let createdAt = Timestamp(Date().timeIntervalSince1970)

        let event = NDKEvent.test(
            kind: 24_111,
            content: "",
            tags: [
                ["e", threadID],
            ],
            pubkey: pubkey,
            createdAt: createdAt
        )

        // When: Converting event to TypingIndicator
        let indicator = try #require(TypingIndicator.from(event: event))

        // Then: TypingIndicator properties match event data
        // Note: event.id is empty for unsigned test events (ID is computed from signature)
        #expect(indicator.pubkey == pubkey)
        #expect(indicator.threadID == threadID)
        #expect(indicator.isTyping == true)
        #expect(indicator.isAgent == false)
        #expect(indicator.createdAt.timeIntervalSince1970 == TimeInterval(createdAt))
    }

    @Test("Parse valid kind:24112 event (agent typing)")
    func parseAgentTypingEvent() throws {
        // Given: A valid kind:24112 event (agent typing)
        let pubkey = "npub1agentpubkey1234567890abcdef"
        let threadID = "thread-id-456"
        let createdAt = Timestamp(Date().timeIntervalSince1970)

        let event = NDKEvent.test(
            kind: 24_112,
            content: "",
            tags: [
                ["e", threadID],
            ],
            pubkey: pubkey,
            createdAt: createdAt
        )

        // When: Converting event to TypingIndicator
        let indicator = try #require(TypingIndicator.from(event: event))

        // Then: TypingIndicator properties match event data
        // Note: event.id is empty for unsigned test events (ID is computed from signature)
        #expect(indicator.pubkey == pubkey)
        #expect(indicator.threadID == threadID)
        #expect(indicator.isTyping == true)
        #expect(indicator.isAgent == true)
        #expect(indicator.createdAt.timeIntervalSince1970 == TimeInterval(createdAt))
    }

    @Test("Extract thread ID from e tag")
    func extractThreadID() throws {
        // Given: Event with thread reference in e tag
        let threadID = "target-thread-id"
        let event = NDKEvent.test(
            kind: 24_111,
            content: "",
            tags: [
                ["e", threadID],
            ],
            pubkey: "testpubkey"
        )

        // When: Converting to TypingIndicator
        let indicator = try #require(TypingIndicator.from(event: event))

        // Then: Thread ID is extracted
        #expect(indicator.threadID == threadID)
    }

    @Test("Return nil for missing e tag")
    func returnNilForMissingETag() {
        // Given: Event without e tag (thread reference)
        let event = NDKEvent.test(
            kind: 24_111,
            content: "",
            tags: [],
            pubkey: "testpubkey"
        )

        // When: Converting to TypingIndicator
        let indicator = TypingIndicator.from(event: event)

        // Then: Returns nil
        #expect(indicator == nil)
    }

    @Test("Return nil for empty e tag value")
    func returnNilForEmptyETag() {
        // Given: Event with empty e tag value
        let event = NDKEvent.test(
            kind: 24_111,
            content: "",
            tags: [
                ["e", ""],
            ],
            pubkey: "testpubkey"
        )

        // When: Converting to TypingIndicator
        let indicator = TypingIndicator.from(event: event)

        // Then: Returns nil
        #expect(indicator == nil)
    }

    @Test("Return nil for wrong kind")
    func returnNilForWrongKind() {
        // Given: Event with wrong kind
        let event = NDKEvent.test(
            kind: 1111, // Wrong kind (should be 24111 or 24112)
            content: "",
            tags: [
                ["e", "thread-id"],
            ],
            pubkey: "testpubkey"
        )

        // When: Converting to TypingIndicator
        let indicator = TypingIndicator.from(event: event)

        // Then: Returns nil
        #expect(indicator == nil)
    }

    @Test("Create filter for fetching typing indicators by thread")
    func createFilterForTypingIndicators() {
        // Given: A thread ID
        let threadID = "thread-123"

        // When: Creating filter for typing indicators
        let filter = TypingIndicator.filter(for: threadID)

        // Then: Filter has correct parameters
        #expect(filter.kinds == [24_111, 24_112])
        #expect(filter.tags?["e"] == [threadID])
    }
}
