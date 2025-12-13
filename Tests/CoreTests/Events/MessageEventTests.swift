//
// MessageEventTests.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation
import NDKSwiftCore
import TENEXCore
import Testing

@Suite("Message Event Tests")
struct MessageEventTests {
    @Test("Parse valid kind:1111 event into Message model")
    func parseValidMessageEvent() throws {
        // Given: A valid kind:1111 event
        let pubkey = "npub1testpubkey1234567890abcdef"
        let threadID = "11:pubkey:thread-id"
        let content = "This is a test message with **markdown**"
        let createdAt = Timestamp(Date().timeIntervalSince1970)
        let replyTo = "parent-event-id"

        let event = NDKEvent(
            pubkey: pubkey,
            createdAt: createdAt,
            kind: 1111,
            tags: [
                ["a", threadID],
                ["e", replyTo],
                ["p", "some-pubkey"],
            ],
            content: content
        )

        // When: Converting event to Message
        let message = try #require(Message.from(event: event))

        // Then: Message properties match event data
        #expect(!message.id.isEmpty)
        #expect(message.pubkey == pubkey)
        #expect(message.threadID == threadID)
        #expect(message.content == content)
        #expect(message.createdAt.timeIntervalSince1970 == TimeInterval(createdAt))
        #expect(message.replyTo == replyTo)
    }

    @Test("Parse message without parent (no e tag)")
    func parseMessageWithoutParent() throws {
        // Given: Event without e tag (top-level message)
        let event = NDKEvent(
            pubkey: "testpubkey",
            kind: 1111,
            tags: [
                ["a", "11:pubkey:thread-id"],
            ],
            content: "Top-level message"
        )

        // When: Converting to Message
        let message = try #require(Message.from(event: event))

        // Then: replyTo is nil
        #expect(message.replyTo == nil)
    }

    @Test("Extract thread ID from a tag")
    func extractThreadID() throws {
        // Given: Event with thread reference in a tag
        let threadID = "11:creator-pubkey:my-awesome-thread"
        let event = NDKEvent(
            pubkey: "testpubkey",
            kind: 1111,
            tags: [
                ["a", threadID],
            ],
            content: "Message content"
        )

        // When: Converting to Message
        let message = try #require(Message.from(event: event))

        // Then: Thread ID is extracted
        #expect(message.threadID == threadID)
    }

    @Test("Extract content as-is (markdown preserved)")
    func extractMarkdownContent() throws {
        // Given: Event with markdown content
        let markdownContent = """
        # Header

        This is **bold** and this is *italic*.

        ```swift
        let code = "block"
        ```
        """
        let event = NDKEvent(
            pubkey: "testpubkey",
            kind: 1111,
            tags: [
                ["a", "11:pubkey:thread-id"],
            ],
            content: markdownContent
        )

        // When: Converting to Message
        let message = try #require(Message.from(event: event))

        // Then: Content is preserved as-is
        #expect(message.content == markdownContent)
    }

    @Test("Handle empty content gracefully")
    func handleEmptyContent() throws {
        // Given: Event with empty content
        let event = NDKEvent(
            pubkey: "testpubkey",
            kind: 1111,
            tags: [
                ["a", "11:pubkey:thread-id"],
            ],
            content: ""
        )

        // When: Converting to Message
        let message = try #require(Message.from(event: event))

        // Then: Content is empty string
        #expect(message.content.isEmpty)
    }

    @Test("Handle multiple e tags (use first one)")
    func handleMultipleETags() throws {
        // Given: Event with multiple e tags
        let firstReply = "first-parent-id"
        let event = NDKEvent(
            pubkey: "testpubkey",
            kind: 1111,
            tags: [
                ["a", "11:pubkey:thread-id"],
                ["e", firstReply],
                ["e", "second-parent-id"],
            ],
            content: "Reply message"
        )

        // When: Converting to Message
        let message = try #require(Message.from(event: event))

        // Then: Uses first e tag
        #expect(message.replyTo == firstReply)
    }

    @Test("Return nil for missing a tag")
    func returnNilForMissingATag() {
        // Given: Event without a tag (thread reference)
        let event = NDKEvent(
            pubkey: "testpubkey",
            kind: 1111,
            tags: [
                ["p", "some-pubkey"],
            ],
            content: "Message"
        )

        // When: Converting to Message
        let message = Message.from(event: event)

        // Then: Returns nil
        #expect(message == nil)
    }

    @Test("Return nil for empty a tag value")
    func returnNilForEmptyATag() {
        // Given: Event with empty a tag value
        let event = NDKEvent(
            pubkey: "testpubkey",
            kind: 1111,
            tags: [
                ["a", ""],
            ],
            content: "Message"
        )

        // When: Converting to Message
        let message = Message.from(event: event)

        // Then: Returns nil
        #expect(message == nil)
    }

    @Test("Return nil for wrong kind")
    func returnNilForWrongKind() {
        // Given: Event with wrong kind
        let event = NDKEvent(
            pubkey: "testpubkey",
            kind: 1, // Wrong kind (should be 1111)
            tags: [
                ["a", "11:pubkey:thread-id"],
            ],
            content: "Message"
        )

        // When: Converting to Message
        let message = Message.from(event: event)

        // Then: Returns nil
        #expect(message == nil)
    }

    @Test("Create filter for fetching messages by thread")
    func createFilterForMessages() {
        // Given: A thread ID
        let threadID = "11:pubkey:my-thread"

        // When: Creating filter for messages
        let filter = Message.filter(for: threadID)

        // Then: Filter has correct parameters
        #expect(filter.kinds == [1111])
        #expect(filter.tags?["a"] == [threadID])
    }
}
