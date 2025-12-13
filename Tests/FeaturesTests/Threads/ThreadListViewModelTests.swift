//
// ThreadListViewModelTests.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation
import NDKSwiftCore
@testable import TENEXCore
@testable import TENEXFeatures
import Testing

@Suite("ThreadListViewModel Tests")
@MainActor
// swiftlint:disable:next type_body_length
struct ThreadListViewModelTests {
    // MARK: Internal

    // MARK: - Initial State Tests

    @Test("ThreadListViewModel starts with empty threads list")
    func startsWithEmptyThreads() async throws {
        let mockNDK = MockNDK()
        let viewModel = ThreadListViewModel(ndk: mockNDK, projectID: "test-project")

        #expect(viewModel.threads.isEmpty)
    }

    @Test("ThreadListViewModel starts with not loading state")
    func startsNotLoading() async throws {
        let mockNDK = MockNDK()
        let viewModel = ThreadListViewModel(ndk: mockNDK, projectID: "test-project")

        #expect(viewModel.isLoading == false)
    }

    @Test("ThreadListViewModel starts with no error")
    func startsWithNoError() async throws {
        let mockNDK = MockNDK()
        let viewModel = ThreadListViewModel(ndk: mockNDK, projectID: "test-project")

        #expect(viewModel.errorMessage == nil)
    }

    // MARK: - Thread Loading Tests

    @Test("ThreadListViewModel loads single thread successfully")
    func loadsSingleThread() async throws {
        let mockNDK = MockNDK()
        let event = createMockThreadEvent(
            threadID: "test-thread",
            projectID: "test-project",
            pubkey: "test-pubkey",
            title: "Test Thread"
        )
        mockNDK.mockEvents = [event]

        let viewModel = ThreadListViewModel(ndk: mockNDK, projectID: "test-project")

        await viewModel.loadThreads()

        #expect(viewModel.threads.count == 1)
        #expect(viewModel.threads[0].id == "test-thread")
        #expect(viewModel.threads[0].title == "Test Thread")
        #expect(viewModel.errorMessage == nil)
    }

    @Test("ThreadListViewModel loads multiple threads successfully")
    func loadsMultipleThreads() async throws {
        let mockNDK = MockNDK()
        let event1 = createMockThreadEvent(
            threadID: "thread-1",
            projectID: "test-project",
            pubkey: "test-pubkey",
            title: "Thread One"
        )
        let event2 = createMockThreadEvent(
            threadID: "thread-2",
            projectID: "test-project",
            pubkey: "test-pubkey",
            title: "Thread Two"
        )
        let event3 = createMockThreadEvent(
            threadID: "thread-3",
            projectID: "test-project",
            pubkey: "test-pubkey",
            title: "Thread Three"
        )
        mockNDK.mockEvents = [event1, event2, event3]

        let viewModel = ThreadListViewModel(ndk: mockNDK, projectID: "test-project")

        await viewModel.loadThreads()

        #expect(viewModel.threads.count == 3)
        #expect(viewModel.threads[0].id == "thread-1")
        #expect(viewModel.threads[1].id == "thread-2")
        #expect(viewModel.threads[2].id == "thread-3")
        #expect(viewModel.errorMessage == nil)
    }

    // MARK: - Error Handling Tests

    @Test("ThreadListViewModel handles error gracefully")
    func handlesErrorGracefully() async throws {
        let mockNDK = MockNDK()
        mockNDK.shouldThrowError = true
        mockNDK.errorToThrow = MockNDK.MockError.subscriptionFailed

        let viewModel = ThreadListViewModel(ndk: mockNDK, projectID: "test-project")

        await viewModel.loadThreads()

        let errorMessage = try #require(viewModel.errorMessage)
        #expect(errorMessage.isEmpty == false)
        #expect(viewModel.isLoading == false)
    }

    @Test("ThreadListViewModel stops loading after error")
    func stopsLoadingAfterError() async throws {
        let mockNDK = MockNDK()
        mockNDK.shouldThrowError = true

        let viewModel = ThreadListViewModel(ndk: mockNDK, projectID: "test-project")

        await viewModel.loadThreads()

        #expect(viewModel.isLoading == false)
    }

    // MARK: - Refresh Tests

    @Test("ThreadListViewModel refresh reloads threads")
    func refreshReloadsThreads() async throws {
        let mockNDK = MockNDK()
        let event1 = createMockThreadEvent(
            threadID: "thread-1",
            projectID: "test-project",
            pubkey: "test-pubkey",
            title: "Thread One"
        )
        mockNDK.mockEvents = [event1]

        let viewModel = ThreadListViewModel(ndk: mockNDK, projectID: "test-project")

        await viewModel.loadThreads()

        #expect(viewModel.threads.count == 1)

        // Add more threads and refresh
        let event2 = createMockThreadEvent(
            threadID: "thread-2",
            projectID: "test-project",
            pubkey: "test-pubkey",
            title: "Thread Two"
        )
        mockNDK.mockEvents = [event1, event2]

        await viewModel.refresh()

        #expect(viewModel.threads.count == 2)
    }

    @Test("ThreadListViewModel refresh clears error message")
    func refreshClearsError() async throws {
        let mockNDK = MockNDK()
        mockNDK.shouldThrowError = true

        let viewModel = ThreadListViewModel(ndk: mockNDK, projectID: "test-project")

        await viewModel.loadThreads()

        #expect(viewModel.errorMessage != nil)

        // Fix the mock and refresh
        mockNDK.shouldThrowError = false
        let event = createMockThreadEvent(
            threadID: "test-thread",
            projectID: "test-project",
            pubkey: "test-pubkey",
            title: "Test Thread"
        )
        mockNDK.mockEvents = [event]

        await viewModel.refresh()

        #expect(viewModel.errorMessage == nil)
    }

    // MARK: - Loading State Tests

    @Test("ThreadListViewModel stops loading after successful fetch")
    func stopsLoadingAfterSuccess() async throws {
        let mockNDK = MockNDK()
        let event = createMockThreadEvent(
            threadID: "test-thread",
            projectID: "test-project",
            pubkey: "test-pubkey",
            title: "Test Thread"
        )
        mockNDK.mockEvents = [event]

        let viewModel = ThreadListViewModel(ndk: mockNDK, projectID: "test-project")

        await viewModel.loadThreads()

        #expect(viewModel.isLoading == false)
    }

    // MARK: - kind:513 Metadata Enrichment Tests

    @Test("ThreadListViewModel enriches thread with kind:513 metadata")
    func enrichThreadWithMetadata() async throws {
        let mockNDK = MockNDK()

        // Create a kind:11 thread without title/summary
        let threadEvent = NDKEvent(
            pubkey: "test-pubkey",
            createdAt: Timestamp(Date().timeIntervalSince1970),
            kind: 11,
            tags: [
                ["d", "thread-123"],
                ["a", "test-project"],
            ],
            content: "{}"
        )

        // Create a kind:513 metadata event with title and summary
        let metadataEvent = NDKEvent(
            pubkey: "test-pubkey",
            createdAt: Timestamp(Date().timeIntervalSince1970),
            kind: 513,
            tags: [
                ["e", "thread-123"],
                ["title", "Enriched Title"],
                ["summary", "Enriched Summary"],
            ],
            content: ""
        )

        mockNDK.mockEvents = [threadEvent, metadataEvent]

        let viewModel = ThreadListViewModel(ndk: mockNDK, projectID: "test-project")

        await viewModel.loadThreads()

        #expect(viewModel.threads.count == 1)
        #expect(viewModel.threads[0].title == "Enriched Title")
        #expect(viewModel.threads[0].summary == "Enriched Summary")
    }

    @Test("ThreadListViewModel handles thread without metadata gracefully")
    func handleThreadWithoutMetadata() async throws {
        let mockNDK = MockNDK()

        // Create a kind:11 thread with inline title
        let threadEvent = createMockThreadEvent(
            threadID: "thread-456",
            projectID: "test-project",
            pubkey: "test-pubkey",
            title: "Inline Title"
        )

        mockNDK.mockEvents = [threadEvent]

        let viewModel = ThreadListViewModel(ndk: mockNDK, projectID: "test-project")

        await viewModel.loadThreads()

        #expect(viewModel.threads.count == 1)
        #expect(viewModel.threads[0].title == "Inline Title")
    }

    @Test("ThreadListViewModel uses newer metadata when timestamps differ")
    func usesNewerMetadataByTimestamp() async throws {
        let mockNDK = MockNDK()

        // Create a kind:11 thread
        let threadEvent = createMockThreadEvent(
            threadID: "thread-timestamp-test",
            projectID: "test-project",
            pubkey: "test-pubkey",
            title: "Original Title"
        )

        // Create older metadata (timestamp: now - 100 seconds)
        let olderMetadata = NDKEvent(
            pubkey: "test-pubkey",
            createdAt: Timestamp(Date().timeIntervalSince1970 - 100),
            kind: 513,
            tags: [
                ["e", "thread-timestamp-test"],
                ["title", "Older Title"],
                ["summary", "Older Summary"],
            ],
            content: ""
        )

        // Create newer metadata (timestamp: now)
        let newerMetadata = NDKEvent(
            pubkey: "test-pubkey",
            createdAt: Timestamp(Date().timeIntervalSince1970),
            kind: 513,
            tags: [
                ["e", "thread-timestamp-test"],
                ["title", "Newer Title"],
                ["summary", "Newer Summary"],
            ],
            content: ""
        )

        // Send events: thread, newer metadata, then older metadata (out of order)
        mockNDK.mockEvents = [threadEvent, newerMetadata, olderMetadata]

        let viewModel = ThreadListViewModel(ndk: mockNDK, projectID: "test-project")

        await viewModel.loadThreads()

        // Should use newer metadata, ignoring the older one
        #expect(viewModel.threads.count == 1)
        #expect(viewModel.threads[0].title == "Newer Title")
        #expect(viewModel.threads[0].summary == "Newer Summary")
    }

    // MARK: - kind:1111 Reply Counting Tests

    @Test("ThreadListViewModel counts kind:1111 replies with uppercase E tag")
    func countRepliesWithUppercaseETag() async throws {
        let mockNDK = MockNDK()

        // Create a kind:11 thread
        let threadEvent = createMockThreadEvent(
            threadID: "thread-789",
            projectID: "test-project",
            pubkey: "test-pubkey",
            title: "Thread with Replies"
        )

        // Create kind:1111 messages with uppercase "E" tag pointing to thread
        let reply1 = NDKEvent(
            pubkey: "user-1",
            createdAt: Timestamp(Date().timeIntervalSince1970),
            kind: 1111, // swiftlint:disable:this number_separator
            tags: [
                ["E", "thread-789"], // Uppercase E for thread root
                ["a", "test-project"],
            ],
            content: "First reply"
        )

        let reply2 = NDKEvent(
            pubkey: "user-2",
            createdAt: Timestamp(Date().timeIntervalSince1970),
            kind: 1111, // swiftlint:disable:this number_separator
            tags: [
                ["E", "thread-789"], // Uppercase E for thread root
                ["a", "test-project"],
            ],
            content: "Second reply"
        )

        let reply3 = NDKEvent(
            pubkey: "user-3",
            createdAt: Timestamp(Date().timeIntervalSince1970),
            kind: 1111, // swiftlint:disable:this number_separator
            tags: [
                ["E", "thread-789"], // Uppercase E for thread root
                ["a", "test-project"],
            ],
            content: "Third reply"
        )

        mockNDK.mockEvents = [threadEvent, reply1, reply2, reply3]

        let viewModel = ThreadListViewModel(ndk: mockNDK, projectID: "test-project")

        await viewModel.loadThreads()

        #expect(viewModel.threads.count == 1)
        #expect(viewModel.threads[0].replyCount == 3)
    }

    @Test("ThreadListViewModel ignores lowercase 'e' tag messages in reply count")
    func ignoreLowercaseETagInReplyCount() async throws {
        let mockNDK = MockNDK()

        // Create a kind:11 thread
        let threadEvent = createMockThreadEvent(
            threadID: "thread-abc",
            projectID: "test-project",
            pubkey: "test-pubkey",
            title: "Thread"
        )

        // Create kind:1111 with uppercase "E" (should count)
        let threadReply = NDKEvent(
            pubkey: "user-1",
            createdAt: Timestamp(Date().timeIntervalSince1970),
            kind: 1111, // swiftlint:disable:this number_separator
            tags: [
                ["E", "thread-abc"], // Uppercase E for thread root
                ["a", "test-project"],
            ],
            content: "Thread reply"
        )

        // Create kind:1111 with lowercase "e" (reply to message, should NOT count)
        let messageReply = NDKEvent(
            pubkey: "user-2",
            createdAt: Timestamp(Date().timeIntervalSince1970),
            kind: 1111, // swiftlint:disable:this number_separator
            tags: [
                ["e", "some-message-id"], // Lowercase e for message reply
                ["a", "test-project"],
            ],
            content: "Message reply"
        )

        mockNDK.mockEvents = [threadEvent, threadReply, messageReply]

        let viewModel = ThreadListViewModel(ndk: mockNDK, projectID: "test-project")

        await viewModel.loadThreads()

        #expect(viewModel.threads.count == 1)
        #expect(viewModel.threads[0].replyCount == 1) // Only uppercase E counted
    }

    // MARK: Private

    // MARK: - Helper Functions

    /// Create a mock thread event for testing
    private func createMockThreadEvent(
        threadID: String,
        projectID: String,
        pubkey: String,
        title: String,
        summary: String? = nil
    ) -> NDKEvent {
        let content = if let summary {
            "{\"summary\": \"\(summary)\"}"
        } else {
            "{}"
        }

        return NDKEvent(
            pubkey: pubkey,
            createdAt: Timestamp(Date().timeIntervalSince1970),
            kind: 11, // Thread kind
            tags: [
                ["d", threadID],
                ["a", projectID],
                ["title", title],
            ],
            content: content
        )
    }
}
