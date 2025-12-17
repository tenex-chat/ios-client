//
// ProjectConversationStoreTests.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation
import NDKSwiftCore
import NDKSwiftTesting
@testable import TENEXCore
@testable import TENEXFeatures
import Testing

@Suite("ProjectConversationStore Tests")
@MainActor
struct ProjectConversationStoreTests {
    // MARK: - Test Constants

    private static let testProjectCoordinate = "31933:\(TestKeyPairs.alice.publicKey):test-project"

    // MARK: - Initialization Tests

    @Test("Initializes with empty state")
    func initializesWithEmptyState() async {
        // Given: A new store
        let ndk = NDK(relayURLs: [])
        let store = ProjectConversationStore(ndk: ndk, projectCoordinate: Self.testProjectCoordinate)

        // Then: Initial state is empty
        #expect(store.threadSummaries.isEmpty)
        #expect(store.activeThreadID == nil)
        #expect(store.activeThreadMessages.isEmpty)
        #expect(store.streamingContent.isEmpty)
    }

    // MARK: - Thread Event Processing (kind:11)

    @Test("Processes thread event and creates summary")
    func processesThreadEvent() async {
        // Given: A store and a thread event
        let ndk = NDK(relayURLs: [])
        let store = ProjectConversationStore(ndk: ndk, projectCoordinate: Self.testProjectCoordinate)

        let threadEvent = NDKEvent.test(
            kind: 11,
            content: "",
            tags: [
                ["a", Self.testProjectCoordinate],
                ["title", "Test Thread Title"],
            ],
            pubkey: TestKeyPairs.alice.publicKey,
            createdAt: 1_700_000_000
        )

        // When: Processing the event
        store.processEvent(threadEvent)

        // Then: Thread summary is created
        #expect(store.threadSummaries.count == 1)
        let summary = store.threadSummaries[threadEvent.id]
        #expect(summary != nil)
        #expect(summary?.id == threadEvent.id)
        #expect(summary?.title == "Test Thread Title")
    }

    @Test("Parses thread metadata correctly")
    func parsesThreadMetadata() async {
        // Given: A store and a thread event with full metadata
        let ndk = NDK(relayURLs: [])
        let store = ProjectConversationStore(ndk: ndk, projectCoordinate: Self.testProjectCoordinate)

        let timestamp: Timestamp = 1_700_000_000
        let threadEvent = NDKEvent.test(
            kind: 11,
            content: "",
            tags: [
                ["a", Self.testProjectCoordinate],
                ["title", "Implementation Plan"],
                ["phase", "planning"],
            ],
            pubkey: TestKeyPairs.alice.publicKey,
            createdAt: timestamp
        )

        // When: Processing the event
        store.processEvent(threadEvent)

        // Then: All metadata is extracted
        let summary = store.threadSummaries[threadEvent.id]
        #expect(summary?.title == "Implementation Plan")
        #expect(summary?.phase == "planning")
        #expect(summary?.createdAt == Date(timeIntervalSince1970: TimeInterval(timestamp)))
        #expect(summary?.replyCount == 0)
    }

    @Test("Updates existing thread summary")
    func updatesExistingThread() async {
        // Given: A store with an existing thread
        let ndk = NDK(relayURLs: [])
        let store = ProjectConversationStore(ndk: ndk, projectCoordinate: Self.testProjectCoordinate)

        // Use a fixed ID so we can update the same thread
        let threadID = "fixed-thread-id-1234567890"
        let originalEvent = NDKEvent(
            id: threadID,
            pubkey: TestKeyPairs.alice.publicKey,
            createdAt: 1_700_000_000,
            kind: 11,
            tags: [
                ["a", Self.testProjectCoordinate],
                ["title", "Original Title"],
            ],
            content: "",
            sig: "test-sig"
        )
        store.processEvent(originalEvent)

        // When: Processing an updated event with same ID
        let updatedEvent = NDKEvent(
            id: threadID,
            pubkey: TestKeyPairs.alice.publicKey,
            createdAt: 1_700_001_000, // Later timestamp
            kind: 11,
            tags: [
                ["a", Self.testProjectCoordinate],
                ["title", "Updated Title"],
            ],
            content: "",
            sig: "test-sig-2"
        )
        store.processEvent(updatedEvent)

        // Then: Thread is updated (not duplicated)
        #expect(store.threadSummaries.count == 1)
        #expect(store.threadSummaries[threadID]?.title == "Updated Title")
    }

    // MARK: - Metadata Event Processing (kind:513)

    @Test("Processes metadata event and creates summary if thread doesn't exist")
    func processesMetadataEventNewThread() async {
        // Given: A store with no threads
        let ndk = NDK(relayURLs: [])
        let store = ProjectConversationStore(ndk: ndk, projectCoordinate: Self.testProjectCoordinate)

        let threadID = "thread-from-metadata-123"
        let metadataEvent = NDKEvent.test(
            kind: 513,
            content: "",
            tags: [
                ["a", Self.testProjectCoordinate],
                ["E", threadID], // Thread ID reference
                ["title", "Thread from Metadata"],
            ],
            pubkey: TestKeyPairs.alice.publicKey,
            createdAt: 1_700_000_000
        )

        // When: Processing the metadata event
        store.processEvent(metadataEvent)

        // Then: Thread summary is created
        #expect(store.threadSummaries.count == 1)
        #expect(store.threadSummaries[threadID]?.title == "Thread from Metadata")
    }

    @Test("Metadata event updates existing thread title")
    func metadataUpdatesExistingThread() async {
        // Given: A store with an existing thread
        let ndk = NDK(relayURLs: [])
        let store = ProjectConversationStore(ndk: ndk, projectCoordinate: Self.testProjectCoordinate)

        let threadID = "existing-thread-456"
        let threadEvent = NDKEvent(
            id: threadID,
            pubkey: TestKeyPairs.alice.publicKey,
            createdAt: 1_700_000_000,
            kind: 11,
            tags: [
                ["a", Self.testProjectCoordinate],
                ["title", "Original Thread Title"],
            ],
            content: "",
            sig: "test-sig"
        )
        store.processEvent(threadEvent)

        // When: Processing a metadata event for the same thread
        let metadataEvent = NDKEvent.test(
            kind: 513,
            content: "",
            tags: [
                ["a", Self.testProjectCoordinate],
                ["E", threadID],
                ["title", "Updated via Metadata"],
            ],
            pubkey: TestKeyPairs.alice.publicKey,
            createdAt: 1_700_001_000
        )
        store.processEvent(metadataEvent)

        // Then: Thread title is updated
        #expect(store.threadSummaries.count == 1)
        #expect(store.threadSummaries[threadID]?.title == "Updated via Metadata")
    }

    @Test("Metadata event updates phase")
    func metadataUpdatesPhase() async {
        // Given: A store with an existing thread
        let ndk = NDK(relayURLs: [])
        let store = ProjectConversationStore(ndk: ndk, projectCoordinate: Self.testProjectCoordinate)

        let threadID = "thread-for-phase-789"
        let threadEvent = NDKEvent(
            id: threadID,
            pubkey: TestKeyPairs.alice.publicKey,
            createdAt: 1_700_000_000,
            kind: 11,
            tags: [
                ["a", Self.testProjectCoordinate],
                ["title", "Test Thread"],
                ["phase", "planning"],
            ],
            content: "",
            sig: "test-sig"
        )
        store.processEvent(threadEvent)

        #expect(store.threadSummaries[threadID]?.phase == "planning")

        // When: Processing metadata that changes the phase
        let metadataEvent = NDKEvent.test(
            kind: 513,
            content: "",
            tags: [
                ["a", Self.testProjectCoordinate],
                ["E", threadID],
                ["title", "Test Thread"],
                ["phase", "implementation"],
            ],
            pubkey: TestKeyPairs.alice.publicKey,
            createdAt: 1_700_001_000
        )
        store.processEvent(metadataEvent)

        // Then: Phase is updated
        #expect(store.threadSummaries[threadID]?.phase == "implementation")
    }

    // MARK: - Message Event Processing (kind:1111)

    @Test("Message event increments reply count")
    func messageIncrementsReplyCount() async {
        // Given: A store with an existing thread
        let ndk = NDK(relayURLs: [])
        let store = ProjectConversationStore(ndk: ndk, projectCoordinate: Self.testProjectCoordinate)

        let threadID = "thread-for-messages-123"
        let threadEvent = NDKEvent(
            id: threadID,
            pubkey: TestKeyPairs.alice.publicKey,
            createdAt: 1_700_000_000,
            kind: 11,
            tags: [
                ["a", Self.testProjectCoordinate],
                ["title", "Test Thread"],
            ],
            content: "",
            sig: "test-sig"
        )
        store.processEvent(threadEvent)

        #expect(store.threadSummaries[threadID]?.replyCount == 0)

        // When: Processing a message event for this thread
        let messageEvent = NDKEvent.test(
            kind: 1111,
            content: "This is a reply",
            tags: [
                ["E", threadID], // Thread root reference
                ["K", "11"],
                ["P", TestKeyPairs.alice.publicKey],
            ],
            pubkey: TestKeyPairs.bob.publicKey,
            createdAt: 1_700_001_000
        )
        store.processEvent(messageEvent)

        // Then: Reply count is incremented
        #expect(store.threadSummaries[threadID]?.replyCount == 1)
    }

    @Test("Message event updates last activity")
    func messageUpdatesLastActivity() async {
        // Given: A store with an existing thread
        let ndk = NDK(relayURLs: [])
        let store = ProjectConversationStore(ndk: ndk, projectCoordinate: Self.testProjectCoordinate)

        let threadID = "thread-for-activity-456"
        let originalTimestamp: Timestamp = 1_700_000_000
        let threadEvent = NDKEvent(
            id: threadID,
            pubkey: TestKeyPairs.alice.publicKey,
            createdAt: originalTimestamp,
            kind: 11,
            tags: [
                ["a", Self.testProjectCoordinate],
                ["title", "Test Thread"],
            ],
            content: "",
            sig: "test-sig"
        )
        store.processEvent(threadEvent)

        let originalLastActivity = Date(timeIntervalSince1970: TimeInterval(originalTimestamp))
        #expect(store.threadSummaries[threadID]?.lastActivity == originalLastActivity)

        // When: Processing a message event with later timestamp
        let messageTimestamp: Timestamp = 1_700_002_000
        let messageEvent = NDKEvent.test(
            kind: 1111,
            content: "Reply message",
            tags: [
                ["E", threadID],
                ["K", "11"],
                ["P", TestKeyPairs.alice.publicKey],
            ],
            pubkey: TestKeyPairs.bob.publicKey,
            createdAt: messageTimestamp
        )
        store.processEvent(messageEvent)

        // Then: Last activity is updated
        let expectedLastActivity = Date(timeIntervalSince1970: TimeInterval(messageTimestamp))
        #expect(store.threadSummaries[threadID]?.lastActivity == expectedLastActivity)
    }

    @Test("Multiple messages increment reply count correctly")
    func multipleMessagesIncrementCount() async {
        // Given: A store with an existing thread
        let ndk = NDK(relayURLs: [])
        let store = ProjectConversationStore(ndk: ndk, projectCoordinate: Self.testProjectCoordinate)

        let threadID = "thread-for-multiple-789"
        let threadEvent = NDKEvent(
            id: threadID,
            pubkey: TestKeyPairs.alice.publicKey,
            createdAt: 1_700_000_000,
            kind: 11,
            tags: [
                ["a", Self.testProjectCoordinate],
                ["title", "Test Thread"],
            ],
            content: "",
            sig: "test-sig"
        )
        store.processEvent(threadEvent)

        // When: Processing multiple message events
        for index in 1 ... 3 {
            let messageEvent = NDKEvent.test(
                kind: 1111,
                content: "Reply \(index)",
                tags: [
                    ["E", threadID],
                    ["K", "11"],
                    ["P", TestKeyPairs.alice.publicKey],
                ],
                pubkey: TestKeyPairs.bob.publicKey,
                createdAt: Timestamp(1_700_000_000 + index * 1000)
            )
            store.processEvent(messageEvent)
        }

        // Then: Reply count reflects all messages
        #expect(store.threadSummaries[threadID]?.replyCount == 3)
    }

    // MARK: - Active Thread Management

    @Test("Open thread sets active thread ID")
    func openThreadSetsActiveID() async {
        // Given: A store with a thread
        let ndk = NDK(relayURLs: [])
        let store = ProjectConversationStore(ndk: ndk, projectCoordinate: Self.testProjectCoordinate)

        let threadID = "thread-to-open-123"
        let threadEvent = NDKEvent(
            id: threadID,
            pubkey: TestKeyPairs.alice.publicKey,
            createdAt: 1_700_000_000,
            kind: 11,
            tags: [
                ["a", Self.testProjectCoordinate],
                ["title", "Test Thread"],
            ],
            content: "",
            sig: "test-sig"
        )
        store.processEvent(threadEvent)

        #expect(store.activeThreadID == nil)

        // When: Opening the thread
        store.openThread(threadID)

        // Then: Active thread ID is set
        #expect(store.activeThreadID == threadID)
    }

    @Test("Open thread loads stored messages")
    func openThreadLoadsMessages() async {
        // Given: A store with a thread and messages
        let ndk = NDK(relayURLs: [])
        let store = ProjectConversationStore(ndk: ndk, projectCoordinate: Self.testProjectCoordinate)

        let threadID = "thread-with-messages-456"
        let threadEvent = NDKEvent(
            id: threadID,
            pubkey: TestKeyPairs.alice.publicKey,
            createdAt: 1_700_000_000,
            kind: 11,
            tags: [
                ["a", Self.testProjectCoordinate],
                ["title", "Test Thread"],
            ],
            content: "",
            sig: "test-sig"
        )
        store.processEvent(threadEvent)

        // Add messages to the thread
        let message1 = NDKEvent.test(
            kind: 1111,
            content: "First message",
            tags: [
                ["E", threadID],
                ["K", "11"],
                ["P", TestKeyPairs.alice.publicKey],
            ],
            pubkey: TestKeyPairs.bob.publicKey,
            createdAt: 1_700_001_000
        )
        let message2 = NDKEvent.test(
            kind: 1111,
            content: "Second message",
            tags: [
                ["E", threadID],
                ["K", "11"],
                ["P", TestKeyPairs.alice.publicKey],
            ],
            pubkey: TestKeyPairs.bob.publicKey,
            createdAt: 1_700_002_000
        )
        store.processEvent(message1)
        store.processEvent(message2)

        #expect(store.activeThreadMessages.isEmpty)

        // When: Opening the thread
        store.openThread(threadID)

        // Then: Messages are loaded
        #expect(store.activeThreadMessages.count == 2)
    }

    @Test("Close thread clears active state")
    func closeThreadClearsState() async {
        // Given: A store with an open thread
        let ndk = NDK(relayURLs: [])
        let store = ProjectConversationStore(ndk: ndk, projectCoordinate: Self.testProjectCoordinate)

        let threadID = "thread-to-close-789"
        let threadEvent = NDKEvent(
            id: threadID,
            pubkey: TestKeyPairs.alice.publicKey,
            createdAt: 1_700_000_000,
            kind: 11,
            tags: [
                ["a", Self.testProjectCoordinate],
                ["title", "Test Thread"],
            ],
            content: "",
            sig: "test-sig"
        )
        store.processEvent(threadEvent)

        let messageEvent = NDKEvent.test(
            kind: 1111,
            content: "A message",
            tags: [
                ["E", threadID],
                ["K", "11"],
                ["P", TestKeyPairs.alice.publicKey],
            ],
            pubkey: TestKeyPairs.bob.publicKey,
            createdAt: 1_700_001_000
        )
        store.processEvent(messageEvent)
        store.openThread(threadID)

        #expect(store.activeThreadID == threadID)
        #expect(store.activeThreadMessages.count == 1)

        // When: Closing the thread
        store.closeThread()

        // Then: Active state is cleared
        #expect(store.activeThreadID == nil)
        #expect(store.activeThreadMessages.isEmpty)
        #expect(store.streamingContent.isEmpty)
    }

    // MARK: - Subscription Lifecycle

    @Test("Subscribe creates subscription")
    func subscribeCreatesSubscription() async {
        // Given: A store
        let ndk = NDK(relayURLs: [])
        let store = ProjectConversationStore(ndk: ndk, projectCoordinate: Self.testProjectCoordinate)

        #expect(store.subscription == nil)

        // When: Subscribing
        store.subscribe()

        // Then: Subscription is created
        #expect(store.subscription != nil)
    }

    @Test("Unsubscribe clears all state")
    func unsubscribeClearsState() async {
        // Given: A store with data
        let ndk = NDK(relayURLs: [])
        let store = ProjectConversationStore(ndk: ndk, projectCoordinate: Self.testProjectCoordinate)

        // Add some state
        let threadID = "thread-to-unsubscribe-123"
        let threadEvent = NDKEvent(
            id: threadID,
            pubkey: TestKeyPairs.alice.publicKey,
            createdAt: 1_700_000_000,
            kind: 11,
            tags: [
                ["a", Self.testProjectCoordinate],
                ["title", "Test Thread"],
            ],
            content: "",
            sig: "test-sig"
        )
        store.processEvent(threadEvent)
        store.openThread(threadID)

        #expect(!store.threadSummaries.isEmpty)
        #expect(store.activeThreadID != nil)

        // When: Unsubscribing
        store.unsubscribe()

        // Then: All state is cleared
        #expect(store.threadSummaries.isEmpty)
        #expect(store.activeThreadID == nil)
        #expect(store.activeThreadMessages.isEmpty)
        #expect(store.streamingContent.isEmpty)
        #expect(store.subscription == nil)
    }
}
