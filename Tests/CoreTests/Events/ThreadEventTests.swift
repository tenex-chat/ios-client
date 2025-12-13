//
// ThreadEventTests.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation
import NDKSwiftCore
import NDKSwiftTesting

// Import Thread struct specifically to override Foundation.Thread
import struct TENEXCore.Thread
import Testing

/// Using Thread from TENEXCore (imported above)
private typealias NostrThread = Thread

// MARK: - ThreadEventTests

@Suite("Thread Event Tests")
struct ThreadEventTests {
    @Test("Parse valid kind:11 event into Thread model")
    func parseValidThreadEvent() throws {
        // Given: A valid kind:11 event
        let threadID = "my-awesome-thread"
        let projectID = "31933:pubkey:project-id"
        let title = "My Awesome Thread"
        let summary = "A thread for testing the Thread model"
        let pubkey = "npub1testpubkey1234567890abcdef"
        let createdAt = Timestamp(Date().timeIntervalSince1970)
        let replyCount = 42

        let event = NDKEvent.test(
            kind: 11,
            content: "{\"summary\": \"\(summary)\"}",
            tags: [
                ["d", threadID],
                ["a", projectID],
                ["title", title],
                ["reply_count", String(replyCount)],
            ],
            pubkey: pubkey,
            createdAt: createdAt
        )

        // When: Converting event to Thread
        let thread = try #require(NostrThread.from(event: event))

        // Then: Thread properties match event data
        // Note: thread.id is the event ID, not the 'd' tag
        #expect(thread.id == event.id)
        #expect(thread.pubkey == pubkey)
        #expect(thread.projectID == projectID)
        #expect(thread.title == title)
        #expect(thread.summary == summary)
        #expect(thread.createdAt.timeIntervalSince1970 == TimeInterval(createdAt))
        #expect(thread.replyCount == replyCount)
    }

    @Test("Extract title from tags")
    func extractTitleFromTags() throws {
        // Given: Event with title tag
        let title = "Thread Title From Tags"
        let event = NDKEvent.test(
            kind: 11,
            content: "{}",
            tags: [
                ["d", "test-thread"],
                ["a", "31933:pubkey:project-id"],
                ["title", title],
            ],
            pubkey: "testpubkey"
        )

        // When: Converting to Thread
        let thread = try #require(NostrThread.from(event: event))

        // Then: Title is extracted
        #expect(thread.title == title)
    }

    @Test("Extract summary from JSON content")
    func extractSummaryFromContent() throws {
        // Given: Event with summary in JSON content
        let summary = "This is a detailed summary"
        let event = NDKEvent.test(
            kind: 11,
            content: "{\"summary\": \"\(summary)\"}",
            tags: [
                ["d", "test-thread"],
                ["a", "31933:pubkey:project-id"],
                ["title", "Test"],
            ],
            pubkey: "testpubkey"
        )

        // When: Converting to Thread
        let thread = try #require(NostrThread.from(event: event))

        // Then: Summary is extracted
        #expect(thread.summary == summary)
    }

    @Test("Handle missing summary gracefully")
    func handleMissingSummary() throws {
        // Given: Event without summary
        let event = NDKEvent.test(
            kind: 11,
            content: "{}",
            tags: [
                ["d", "test-thread"],
                ["a", "31933:pubkey:project-id"],
                ["title", "Test"],
            ],
            pubkey: "testpubkey"
        )

        // When: Converting to Thread
        let thread = try #require(NostrThread.from(event: event))

        // Then: Summary is nil
        #expect(thread.summary == nil)
    }

    @Test("Handle invalid JSON content gracefully")
    func handleInvalidJSON() throws {
        // Given: Event with invalid JSON content
        let event = NDKEvent.test(
            kind: 11,
            content: "not valid json",
            tags: [
                ["d", "test-thread"],
                ["a", "31933:pubkey:project-id"],
                ["title", "Test"],
            ],
            pubkey: "testpubkey"
        )

        // When: Converting to Thread
        let thread = try #require(NostrThread.from(event: event))

        // Then: Summary is nil (gracefully handled)
        #expect(thread.summary == nil)
    }

    @Test("Handle missing reply count gracefully")
    func handleMissingReplyCount() throws {
        // Given: Event without reply_count tag
        let event = NDKEvent.test(
            kind: 11,
            content: "{}",
            tags: [
                ["d", "test-thread"],
                ["a", "31933:pubkey:project-id"],
                ["title", "Test"],
            ],
            pubkey: "testpubkey"
        )

        // When: Converting to Thread
        let thread = try #require(NostrThread.from(event: event))

        // Then: Reply count defaults to 0
        #expect(thread.replyCount == 0)
    }

    @Test("Handle missing phase gracefully")
    func handleMissingPhase() throws {
        // Given: Event without phase tag
        let event = NDKEvent.test(
            kind: 11,
            content: "{}",
            tags: [
                ["d", "test-thread"],
                ["a", "31933:pubkey:project-id"],
                ["title", "Test"],
            ],
            pubkey: "testpubkey"
        )

        // When: Converting to Thread
        let thread = try #require(NostrThread.from(event: event))

        // Then: Phase is nil
        #expect(thread.phase == nil)
    }

    @Test("Extract phase from tags")
    func extractPhaseFromTags() throws {
        // Given: Event with phase tag
        let phase = "development"
        let event = NDKEvent.test(
            kind: 11,
            content: "{}",
            tags: [
                ["d", "test-thread"],
                ["a", "31933:pubkey:project-id"],
                ["title", "Test"],
                ["phase", phase],
            ],
            pubkey: "testpubkey"
        )

        // When: Converting to Thread
        let thread = try #require(NostrThread.from(event: event))

        // Then: Phase is extracted
        #expect(thread.phase == phase)
    }

    @Test("Thread without d tag still parses successfully")
    func threadWithoutDTag() throws {
        // Given: Event without d tag (d tag is not required - thread uses event.id)
        let event = NDKEvent.test(
            kind: 11,
            content: "{}",
            tags: [
                ["a", "31933:pubkey:project-id"],
                ["title", "Test"],
            ],
            pubkey: "testpubkey"
        )

        // When: Converting to Thread
        let thread = try #require(NostrThread.from(event: event))

        // Then: Thread is created with event.id as its ID
        #expect(thread.id == event.id)
        #expect(thread.title == "Test")
    }

    @Test("Return nil for missing a tag")
    func returnNilForMissingATag() {
        // Given: Event without a tag (project reference)
        let event = NDKEvent.test(
            kind: 11,
            content: "{}",
            tags: [
                ["d", "test-thread"],
                ["title", "Test"],
            ],
            pubkey: "testpubkey"
        )

        // When: Converting to Thread
        let thread = NostrThread.from(event: event)

        // Then: Returns nil
        #expect(thread == nil)
    }

    @Test("Return nil for missing title tag")
    func returnNilForMissingTitleTag() {
        // Given: Event without title tag
        let event = NDKEvent.test(
            kind: 11,
            content: "{}",
            tags: [
                ["d", "test-thread"],
                ["a", "31933:pubkey:project-id"],
            ],
            pubkey: "testpubkey"
        )

        // When: Converting to Thread
        let thread = NostrThread.from(event: event)

        // Then: Returns nil
        #expect(thread == nil)
    }

    @Test("Return nil for wrong kind")
    func returnNilForWrongKind() {
        // Given: Event with wrong kind
        let event = NDKEvent.test(
            kind: 1, // Wrong kind
            content: "{}",
            tags: [
                ["d", "test-thread"],
                ["a", "31933:pubkey:project-id"],
                ["title", "Test"],
            ],
            pubkey: "testpubkey"
        )

        // When: Converting to Thread
        let thread = NostrThread.from(event: event)

        // Then: Returns nil
        #expect(thread == nil)
    }

    @Test("Create filter for fetching threads by project")
    func createFilterForThreads() {
        // Given: A project ID
        let projectID = "31933:pubkey:my-project"

        // When: Creating filter for threads
        let filter = NostrThread.filter(for: projectID)

        // Then: Filter has correct parameters
        #expect(filter.kinds == [11])
        #expect(filter.tags?["a"] == [projectID])
    }
}
