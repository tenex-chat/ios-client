//
// ConversationMetadataTests.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation
import NDKSwiftCore
@testable import TENEXCore
import Testing

@Suite("ConversationMetadata Event Tests")
struct ConversationMetadataTests {
    @Test("Parse valid kind:513 conversation metadata with title and summary")
    func parseValidMetadataWithTitleAndSummary() throws {
        let event = NDKEvent(
            pubkey: "test-pubkey",
            createdAt: Timestamp(1_234_567_890),
            kind: 513,
            tags: [
                ["e", "thread-123"],
                ["title", "Test Conversation"],
                ["summary", "This is a test conversation summary"],
            ],
            content: ""
        )

        let metadata = try #require(ConversationMetadata.from(event: event))

        #expect(metadata.threadID == "thread-123")
        #expect(metadata.pubkey == "test-pubkey")
        #expect(metadata.title == "Test Conversation")
        #expect(metadata.summary == "This is a test conversation summary")
    }

    @Test("Parse valid kind:513 conversation metadata with title only")
    func parseValidMetadataWithTitleOnly() throws {
        let event = NDKEvent(
            pubkey: "test-pubkey",
            createdAt: Timestamp(1_234_567_890),
            kind: 513,
            tags: [
                ["e", "thread-456"],
                ["title", "Another Conversation"],
            ],
            content: ""
        )

        let metadata = try #require(ConversationMetadata.from(event: event))

        #expect(metadata.threadID == "thread-456")
        #expect(metadata.title == "Another Conversation")
        #expect(metadata.summary == nil)
    }

    @Test("Reject kind:513 event without 'e' tag")
    func rejectMetadataWithoutETag() {
        let event = NDKEvent(
            pubkey: "test-pubkey",
            createdAt: Timestamp(1_234_567_890),
            kind: 513,
            tags: [
                ["title", "Test"],
            ],
            content: ""
        )

        let metadata = ConversationMetadata.from(event: event)
        #expect(metadata == nil)
    }

    @Test("Reject non-513 event")
    func rejectNon513Event() {
        let event = NDKEvent(
            pubkey: "test-pubkey",
            createdAt: Timestamp(1_234_567_890),
            kind: 11, // Wrong kind
            tags: [
                ["e", "thread-123"],
                ["title", "Test"],
            ],
            content: ""
        )

        let metadata = ConversationMetadata.from(event: event)
        #expect(metadata == nil)
    }

    @Test("Create filter for thread metadata")
    func createFilterForThreadMetadata() {
        let filter = ConversationMetadata.filter(for: "thread-123")

        #expect(filter.kinds == [513])
        #expect(filter.tags?["e"] == ["thread-123"])
    }
}
