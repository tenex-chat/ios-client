//
// InboxStoreTests.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation
import NDKSwiftCore
import NDKSwiftTesting
import TENEXCore
@testable import TENEXFeatures
import Testing

@Suite("InboxStore Tests")
@MainActor
// swiftlint:disable type_body_length
struct InboxStoreTests {
    // MARK: - Initialization Tests

    @Test("InboxStore initializes with empty state")
    func initializesWithEmptyState() async {
        // Given: A new InboxStore
        let store = InboxStore()

        // Then: Initial state is empty
        #expect(store.events.isEmpty)
        #expect(store.unreadCount == 0)
        #expect(store.isLoading == false)
        #expect(store.lastVisit > 0) // Should have a default timestamp
    }

    @Test("InboxStore loads persisted last visit timestamp")
    func loadsPersistedLastVisit() async {
        // Given: A persisted timestamp
        let persistedTimestamp = Date().addingTimeInterval(-3600).timeIntervalSince1970
        UserDefaults.standard.set(persistedTimestamp, forKey: "inbox_last_visit")

        // When: Creating a new store
        let store = InboxStore()

        // Then: Last visit is loaded from storage
        #expect(store.lastVisit == persistedTimestamp)

        // Cleanup
        UserDefaults.standard.removeObject(forKey: "inbox_last_visit")
    }

    // MARK: - Event Subscription Tests

    @Test("Subscribe creates subscription with correct filter")
    func subscribeCreatesCorrectFilter() async {
        // Given: An InboxStore and NDK instance
        let store = InboxStore()
        let ndk = NDK(relayURLs: [])
        let userPubkey = "test-user-pubkey"

        // When: Subscribing to inbox events
        await store.subscribe(ndk: ndk, userPubkey: userPubkey)

        // Then: Subscription should be created
        // Note: This test verifies the subscription is initiated
        // Actual filter validation would require NDK mock
        #expect(store.isLoading == true)
    }

    @Test("Handles incoming events and updates state")
    func handlesIncomingEvents() async {
        // Given: An InboxStore with a subscription
        let store = InboxStore()
        let ndk = NDK(relayURLs: [])
        let userPubkey = "test-user-pubkey"

        // Create test events
        let event1 = NDKEvent.test(
            kind: 1111,
            content: "Agent response",
            pubkey: "agent-pubkey",
            tags: [["p", userPubkey]]
        )
        let event2 = NDKEvent.test(
            kind: 1,
            content: "Mention",
            pubkey: "other-user",
            tags: [["p", userPubkey]]
        )

        // When: Events are received
        await store.subscribe(ndk: ndk, userPubkey: userPubkey)
        await store.handleEvent(event1)
        await store.handleEvent(event2)

        // Then: Events are stored and sorted by recency
        #expect(store.events.count == 2)
        #expect(store.isLoading == false)
    }

    // MARK: - Event Deduplication Tests

    @Test("Deduplicates events by E tag - keeps most recent")
    func deduplicatesEventsByETag() async {
        // Given: Multiple events with the same E tag
        let rootEventID = "root-event-id"
        let event1 = NDKEvent.test(
            kind: 1111,
            content: "First response",
            pubkey: "agent-pubkey",
            tags: [["E", rootEventID]],
            createdAt: Date().addingTimeInterval(-3600) // 1 hour ago
        )
        let event2 = NDKEvent.test(
            kind: 1111,
            content: "Second response",
            pubkey: "agent-pubkey",
            tags: [["E", rootEventID]],
            createdAt: Date().addingTimeInterval(-1800) // 30 min ago
        )
        let event3 = NDKEvent.test(
            kind: 1111,
            content: "Latest response",
            pubkey: "agent-pubkey",
            tags: [["E", rootEventID]],
            createdAt: Date() // Now
        )

        let events = [event1, event2, event3]

        // When: Deduplicating events
        let store = InboxStore()
        let deduplicated = store.deduplicateByETag(events)

        // Then: Only the most recent event is kept
        #expect(deduplicated.count == 1)
        #expect(deduplicated.first?.content == "Latest response")
    }

    @Test("Deduplication preserves events without E tag")
    func deduplicationPreservesEventsWithoutETag() async {
        // Given: Events without E tags (different conversations)
        let event1 = NDKEvent.test(
            kind: 1,
            content: "Mention 1",
            pubkey: "user1"
        )
        let event2 = NDKEvent.test(
            kind: 1,
            content: "Mention 2",
            pubkey: "user2"
        )
        let event3 = NDKEvent.test(
            kind: 7,
            content: "❤️",
            pubkey: "user3"
        )

        let events = [event1, event2, event3]

        // When: Deduplicating events
        let store = InboxStore()
        let deduplicated = store.deduplicateByETag(events)

        // Then: All events are preserved
        #expect(deduplicated.count == 3)
    }

    @Test("Deduplication handles mixed events (with and without E tags)")
    func deduplicationHandlesMixedEvents() async {
        // Given: Mix of events with and without E tags
        let rootID = "root-id"
        let event1 = NDKEvent.test(
            kind: 1111,
            content: "Response 1",
            pubkey: "agent",
            tags: [["E", rootID]],
            createdAt: Date().addingTimeInterval(-100)
        )
        let event2 = NDKEvent.test(
            kind: 1111,
            content: "Response 2",
            pubkey: "agent",
            tags: [["E", rootID]],
            createdAt: Date()
        )
        let event3 = NDKEvent.test(
            kind: 1,
            content: "Standalone mention",
            pubkey: "user"
        )

        let events = [event1, event2, event3]

        // When: Deduplicating
        let store = InboxStore()
        let deduplicated = store.deduplicateByETag(events)

        // Then: Latest from E-tag group + standalone event
        #expect(deduplicated.count == 2)
        #expect(deduplicated.contains { $0.content == "Response 2" })
        #expect(deduplicated.contains { $0.content == "Standalone mention" })
    }

    // MARK: - Event Sorting Tests

    @Test("Events are sorted by creation time (newest first)")
    func eventsSortedByCreationTime() async {
        // Given: Events with different timestamps
        let event1 = NDKEvent.test(
            kind: 1,
            content: "Oldest",
            pubkey: "user1",
            createdAt: Date().addingTimeInterval(-7200) // 2 hours ago
        )
        let event2 = NDKEvent.test(
            kind: 1,
            content: "Middle",
            pubkey: "user2",
            createdAt: Date().addingTimeInterval(-3600) // 1 hour ago
        )
        let event3 = NDKEvent.test(
            kind: 1,
            content: "Newest",
            pubkey: "user3",
            createdAt: Date()
        )

        let events = [event1, event2, event3]

        // When: Sorting events
        let store = InboxStore()
        let sorted = store.sortEventsByTime(events)

        // Then: Events are in reverse chronological order
        #expect(sorted[0].content == "Newest")
        #expect(sorted[1].content == "Middle")
        #expect(sorted[2].content == "Oldest")
    }

    // MARK: - Unread Count Tests

    @Test("Calculates unread count based on last visit")
    func calculatesUnreadCount() async {
        // Given: Events before and after last visit
        let lastVisit = Date().addingTimeInterval(-3600).timeIntervalSince1970 // 1 hour ago
        let store = InboxStore()
        store.updateLastVisit(lastVisit)

        let oldEvent = NDKEvent.test(
            kind: 1,
            content: "Old event",
            pubkey: "user1",
            createdAt: Date().addingTimeInterval(-7200) // 2 hours ago (before last visit)
        )
        let newEvent1 = NDKEvent.test(
            kind: 1,
            content: "New event 1",
            pubkey: "user2",
            createdAt: Date().addingTimeInterval(-1800) // 30 min ago (after last visit)
        )
        let newEvent2 = NDKEvent.test(
            kind: 1,
            content: "New event 2",
            pubkey: "user3",
            createdAt: Date() // Now (after last visit)
        )

        // When: Adding events
        store.events = [oldEvent, newEvent1, newEvent2]
        store.recalculateUnreadCount()

        // Then: Unread count reflects events after last visit
        #expect(store.unreadCount == 2)
    }

    @Test("isEventUnread correctly identifies unread events")
    func isEventUnreadIdentifiesCorrectly() async {
        // Given: Store with last visit timestamp
        let store = InboxStore()
        let lastVisit = Date().addingTimeInterval(-3600).timeIntervalSince1970
        store.updateLastVisit(lastVisit)

        let oldEvent = NDKEvent.test(
            kind: 1,
            content: "Old",
            pubkey: "user",
            createdAt: Date().addingTimeInterval(-7200)
        )
        let newEvent = NDKEvent.test(
            kind: 1,
            content: "New",
            pubkey: "user",
            createdAt: Date()
        )

        // When: Checking if events are unread
        let oldIsUnread = store.isEventUnread(oldEvent)
        let newIsUnread = store.isEventUnread(newEvent)

        // Then: Only new event is unread
        #expect(oldIsUnread == false)
        #expect(newIsUnread == true)
    }

    // MARK: - Mark as Read Tests

    @Test("markAllRead updates last visit and recalculates unread count")
    func markAllReadUpdatesState() async {
        // Given: Store with unread events
        let store = InboxStore()
        let oldTimestamp = Date().addingTimeInterval(-7200).timeIntervalSince1970
        store.updateLastVisit(oldTimestamp)

        let event = NDKEvent.test(
            kind: 1,
            content: "New event",
            pubkey: "user",
            createdAt: Date()
        )
        store.events = [event]
        store.recalculateUnreadCount()

        // Verify there's an unread event
        #expect(store.unreadCount == 1)

        // When: Marking all as read
        let beforeMark = Date().timeIntervalSince1970
        store.markAllRead()
        let afterMark = Date().timeIntervalSince1970

        // Then: Last visit is updated and unread count is zero
        #expect(store.lastVisit >= beforeMark)
        #expect(store.lastVisit <= afterMark)
        #expect(store.unreadCount == 0)
    }

    @Test("markAllRead persists last visit timestamp")
    func markAllReadPersistsTimestamp() async {
        // Given: A store
        let store = InboxStore()

        // When: Marking all as read
        store.markAllRead()

        // Then: Timestamp is persisted to UserDefaults
        let persisted = UserDefaults.standard.double(forKey: "inbox_last_visit")
        #expect(persisted > 0)
        #expect(abs(persisted - store.lastVisit) < 1) // Within 1 second

        // Cleanup
        UserDefaults.standard.removeObject(forKey: "inbox_last_visit")
    }

    // MARK: - Event Filter Tests

    @Test("Filters include correct event kinds")
    func filtersIncludeCorrectEventKinds() async {
        // Given: Events of various kinds
        let mentionEvent = NDKEvent.test(kind: 1, content: "Mention", pubkey: "user1")
        let replyEvent = NDKEvent.test(kind: 1111, content: "Reply", pubkey: "agent1")
        let reactionEvent = NDKEvent.test(kind: 7, content: "❤️", pubkey: "user2")
        let articleEvent = NDKEvent.test(kind: 30_023, content: "Article", pubkey: "user3")
        let ignoredEvent = NDKEvent.test(kind: 3, content: "Contacts", pubkey: "user4") // Should be ignored

        // When: Checking which kinds are valid inbox events
        let store = InboxStore()
        #expect(store.isValidInboxEventKind(1) == true)
        #expect(store.isValidInboxEventKind(1111) == true)
        #expect(store.isValidInboxEventKind(7) == true)
        #expect(store.isValidInboxEventKind(30_023) == true)
        #expect(store.isValidInboxEventKind(3) == false)
    }

    // MARK: - Event Time Window Tests

    @Test("Subscription filters events from last 7 days")
    func subscriptionFiltersLast7Days() async {
        // Given: Current timestamp
        let now = Date()
        let sevenDaysInSeconds: TimeInterval = 7 * 24 * 60 * 60
        let sevenDaysAgo = now.addingTimeInterval(-sevenDaysInSeconds)

        // When: Creating subscription filter
        let store = InboxStore()
        let filter = store.createSubscriptionFilter(
            userPubkey: "test-pubkey",
            since: sevenDaysAgo
        )

        // Then: Filter includes correct since timestamp
        if let filterSince = filter.since {
            #expect(filterSince >= sevenDaysAgo.timeIntervalSince1970 - 1) // Allow 1s tolerance
        }
        #expect(filter.kinds == [1, 1111, 7, 30_023])
        #expect(filter.tags["p"] == ["test-pubkey"])
    }

    // MARK: - Cleanup Tests

    @Test("cleanup stops subscription and clears state")
    func cleanupStopsSubscriptionAndClearsState() async {
        // Given: Store with active subscription and events
        let store = InboxStore()
        let ndk = NDK(relayURLs: [])
        await store.subscribe(ndk: ndk, userPubkey: "test-user")

        let event = NDKEvent.test(kind: 1, content: "Test", pubkey: "user")
        await store.handleEvent(event)

        #expect(!store.events.isEmpty)

        // When: Cleaning up
        await store.cleanup()

        // Then: State is cleared
        #expect(store.events.isEmpty)
        #expect(store.unreadCount == 0)
        #expect(store.isLoading == false)
    }

    // MARK: - Event Type Detection Tests

    @Test("Detects agent response events")
    func detectsAgentResponseEvents() async {
        // Given: Event with agent markers
        let agentEvent = NDKEvent.test(
            kind: 1111,
            content: "Agent response",
            pubkey: "agent-pubkey",
            tags: [
                ["client", "TENEX Agent"],
                ["p", "user-pubkey", "", "agent"],
            ]
        )

        // When: Checking event type
        let store = InboxStore()
        let eventType = store.getEventType(agentEvent)

        // Then: Detected as agent response
        #expect(eventType == .agentResponse)
    }

    @Test("Detects regular mention events")
    func detectsRegularMentionEvents() async {
        // Given: Regular kind:1 event
        let mentionEvent = NDKEvent.test(
            kind: 1,
            content: "Hey @user, check this out",
            pubkey: "other-user",
            tags: [["p", "user-pubkey"]]
        )

        // When: Checking event type
        let store = InboxStore()
        let eventType = store.getEventType(mentionEvent)

        // Then: Detected as mention
        #expect(eventType == .mention)
    }

    @Test("Detects reaction events")
    func detectsReactionEvents() async {
        // Given: Kind:7 reaction event
        let reactionEvent = NDKEvent.test(
            kind: 7,
            content: "❤️",
            pubkey: "reactor-pubkey",
            tags: [["p", "user-pubkey"]]
        )

        // When: Checking event type
        let store = InboxStore()
        let eventType = store.getEventType(reactionEvent)

        // Then: Detected as reaction
        #expect(eventType == .reaction)
    }

    @Test("Detects reply events")
    func detectsReplyEvents() async {
        // Given: Kind:1111 event without agent markers
        let replyEvent = NDKEvent.test(
            kind: 1111,
            content: "Reply to your message",
            pubkey: "other-user",
            tags: [["p", "user-pubkey"]]
        )

        // When: Checking event type
        let store = InboxStore()
        let eventType = store.getEventType(replyEvent)

        // Then: Detected as reply
        #expect(eventType == .reply)
    }

    // MARK: - Suggestion Detection Tests

    @Test("Detects events with suggestions")
    func detectsEventsWithSuggestions() async {
        // Given: Event with suggestion tags
        let eventWithSuggestions = NDKEvent.test(
            kind: 1111,
            content: "Which option?",
            pubkey: "agent",
            tags: [
                ["suggestion", "Option 1"],
                ["suggestion", "Option 2"],
                ["suggestion", "Option 3"],
            ]
        )

        // When: Extracting suggestions
        let store = InboxStore()
        let suggestions = store.getSuggestions(from: eventWithSuggestions)

        // Then: All suggestions are extracted
        #expect(suggestions.count == 3)
        #expect(suggestions.contains("Option 1"))
        #expect(suggestions.contains("Option 2"))
        #expect(suggestions.contains("Option 3"))
    }

    @Test("Returns empty array for events without suggestions")
    func returnsEmptyArrayForNoSuggestions() async {
        // Given: Event without suggestion tags
        let eventWithoutSuggestions = NDKEvent.test(
            kind: 1,
            content: "Regular message",
            pubkey: "user"
        )

        // When: Extracting suggestions
        let store = InboxStore()
        let suggestions = store.getSuggestions(from: eventWithoutSuggestions)

        // Then: Empty array is returned
        #expect(suggestions.isEmpty)
    }
}

// swiftlint:enable type_body_length
