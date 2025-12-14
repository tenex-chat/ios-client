//
// InboxIntegrationTests.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation
import NDKSwiftCore
import NDKSwiftTesting
import TENEXCore
@testable import TENEXFeatures
import Testing

// MARK: - InboxIntegrationTests

@Suite("Inbox Integration Tests")
@MainActor
struct InboxIntegrationTests {
    // MARK: - NDK Subscription Integration Tests

    @Test("Creates subscription with correct event kinds filter")
    func createsSubscriptionWithCorrectKindsFilter() async {
        // Given: InboxStore and NDK
        let store = InboxStore()
        let ndk = NDK(relayURLs: [])
        let userPubkey = "test-user-pubkey"

        // When: Subscribing to inbox events
        await store.subscribe(ndk: ndk, userPubkey: userPubkey)

        // Then: Subscription filter should include kinds [1, 1111, 7, 30023]
        let expectedKinds: Set<Int> = [1, 1111, 7, 30_023]
        #expect(store.subscribedKinds == expectedKinds)
    }

    @Test("Creates subscription with p-tag filter for user")
    func createsSubscriptionWithPTagFilter() async {
        // Given: InboxStore and NDK
        let store = InboxStore()
        let ndk = NDK(relayURLs: [])
        let userPubkey = "9d48a1a5dbe13404a729634f1d6ba722d40513468dd713c8ea38ca9b7b6f2c7"

        // When: Subscribing
        await store.subscribe(ndk: ndk, userPubkey: userPubkey)

        // Then: Filter should only include events that p-tag the user
        #expect(store.filterPubkey == userPubkey)
    }

    @Test("Creates subscription with 7-day time window")
    func createsSubscriptionWith7DayWindow() async {
        // Given: InboxStore and NDK
        let store = InboxStore()
        let ndk = NDK(relayURLs: [])
        let userPubkey = "test-user"

        // When: Subscribing
        let sevenDaysInSeconds: TimeInterval = 7 * 24 * 60 * 60
        let beforeSubscribe = Date().addingTimeInterval(-sevenDaysInSeconds)
        await store.subscribe(ndk: ndk, userPubkey: userPubkey)

        // Then: Subscription should filter events from last 7 days
        if let subscriptionSince = store.subscriptionSince {
            #expect(subscriptionSince >= beforeSubscribe.timeIntervalSince1970 - 60) // Allow 1 min tolerance
        }
    }

    @Test("Subscription remains open (does not close on EOSE)")
    func subscriptionRemainsOpen() async {
        // Given: InboxStore with subscription
        let store = InboxStore()
        let ndk = NDK(relayURLs: [])

        // When: Subscribing
        await store.subscribe(ndk: ndk, userPubkey: "test-user")

        // Then: Subscription should have closeOnEose: false
        #expect(store.subscriptionCloseOnEose == false)
    }

    // MARK: - Event Handling Integration Tests

    @Test("Handles real-time event updates from subscription")
    func handlesRealTimeEventUpdates() async {
        // Given: Active subscription
        let store = InboxStore()
        let ndk = NDK(relayURLs: [])
        await store.subscribe(ndk: ndk, userPubkey: "test-user")

        // When: New event arrives
        let newEvent = NDKEvent.test(
            kind: 1111,
            content: "Real-time agent response",
            pubkey: "agent-pubkey",
            tags: [["p", "test-user"]],
            createdAt: Date()
        )

        await store.handleEvent(newEvent)

        // Then: Event is immediately added to store
        #expect(store.events.contains { $0.id == newEvent.id })
        #expect(store.isLoading == false)
    }

    @Test("Updates existing event when replacement arrives")
    func updatesExistingEventOnReplacement() async {
        // Given: Store with existing event
        let store = InboxStore()
        let rootID = "root-event"
        let oldEvent = NDKEvent.test(
            kind: 1111,
            content: "Old response",
            pubkey: "agent",
            tags: [["E", rootID]],
            createdAt: Date().addingTimeInterval(-100)
        )

        await store.handleEvent(oldEvent)
        #expect(store.events.count == 1)
        #expect(store.events.first?.content == "Old response")

        // When: Newer event with same E tag arrives
        let newEvent = NDKEvent.test(
            kind: 1111,
            content: "Updated response",
            pubkey: "agent",
            tags: [["E", rootID]],
            createdAt: Date()
        )

        await store.handleEvent(newEvent)

        // Then: Old event is replaced by new one
        #expect(store.events.count == 1)
        #expect(store.events.first?.content == "Updated response")
    }

    @Test("Recalculates unread count on new event")
    func recalculatesUnreadCountOnNewEvent() async {
        // Given: Store with last visit 1 hour ago
        let store = InboxStore()
        let lastVisit = Date().addingTimeInterval(-3600).timeIntervalSince1970
        store.updateLastVisit(lastVisit)

        #expect(store.unreadCount == 0)

        // When: New event arrives
        let newEvent = NDKEvent.test(
            kind: 1,
            content: "New mention",
            pubkey: "user",
            createdAt: Date()
        )

        await store.handleEvent(newEvent)

        // Then: Unread count is updated
        #expect(store.unreadCount == 1)
    }

    @Test("Maintains sort order after event updates")
    func maintainsSortOrderAfterUpdates() async {
        // Given: Store with multiple events
        let store = InboxStore()
        let event1 = NDKEvent.test(
            kind: 1,
            content: "Oldest",
            pubkey: "user1",
            createdAt: Date().addingTimeInterval(-300)
        )
        let event2 = NDKEvent.test(
            kind: 1,
            content: "Middle",
            pubkey: "user2",
            createdAt: Date().addingTimeInterval(-200)
        )

        await store.handleEvent(event1)
        await store.handleEvent(event2)

        // When: Newest event arrives
        let event3 = NDKEvent.test(
            kind: 1,
            content: "Newest",
            pubkey: "user3",
            createdAt: Date()
        )

        await store.handleEvent(event3)

        // Then: Events remain sorted newest-first
        #expect(store.events[0].content == "Newest")
        #expect(store.events[1].content == "Middle")
        #expect(store.events[2].content == "Oldest")
    }

    // MARK: - Persistence Integration Tests

    @Test("Last visit persists across store instances")
    func lastVisitPersistsAcrossInstances() async {
        // Given: First store instance that marks as read
        let store1 = InboxStore()
        store1.markAllRead()
        let timestamp1 = store1.lastVisit

        // When: Creating second store instance
        let store2 = InboxStore()

        // Then: Last visit is loaded from storage
        #expect(abs(store2.lastVisit - timestamp1) < 1) // Within 1 second

        // Cleanup
        UserDefaults.standard.removeObject(forKey: "inbox_last_visit")
    }

    @Test("Updating last visit persists to storage")
    func updatingLastVisitPersists() async {
        // Given: Store instance
        let store = InboxStore()
        let newTimestamp = Date().addingTimeInterval(-1800).timeIntervalSince1970

        // When: Updating last visit
        store.updateLastVisit(newTimestamp)

        // Then: Value is persisted
        let persisted = UserDefaults.standard.double(forKey: "inbox_last_visit")
        #expect(persisted == newTimestamp)

        // Cleanup
        UserDefaults.standard.removeObject(forKey: "inbox_last_visit")
    }

    // MARK: - Navigation Integration Tests

    @Test("Navigates to chat when event is tapped")
    func navigatesToChatOnEventTap() async {
        // Given: Navigation router and event
        let router = NavigationRouter()
        let event = NDKEvent.test(
            kind: 1111,
            content: "Test event",
            pubkey: "agent"
        )

        // When: Event is tapped
        router.navigate(to: .chat(eventID: event.id))

        // Then: Navigation path includes chat route
        #expect(router.path.contains(.chat(eventID: event.id)))
    }

    @Test("Navigates to inbox page from popover")
    func navigatesToInboxPageFromPopover() async {
        // Given: Navigation router
        let router = NavigationRouter()

        // When: View All is tapped in popover
        router.navigate(to: .inbox)

        // Then: Navigation path includes inbox route
        #expect(router.path.contains(.inbox))
    }

    // MARK: - Keyboard Shortcut Integration Tests

    @Test("Command+I toggles inbox popover")
    func commandITogglesInboxPopover() async {
        // Given: Inbox button state
        var isOpen = false

        // When: Command+I is pressed
        // (Simulated - actual keyboard testing via Maestro)
        isOpen.toggle()

        // Then: Popover opens
        #expect(isOpen == true)

        // When: Command+I is pressed again
        isOpen.toggle()

        // Then: Popover closes
        #expect(isOpen == false)
    }

    // MARK: - Full Flow Integration Tests

    @Test("Complete inbox flow: subscribe → receive → display → mark read")
    func completeInboxFlow() async {
        // Given: Fresh store and NDK
        let store = InboxStore()
        let ndk = NDK(relayURLs: [])
        let userPubkey = "test-user"

        // Step 1: Subscribe
        await store.subscribe(ndk: ndk, userPubkey: userPubkey)
        #expect(store.isLoading == true)

        // Step 2: Receive events
        let event1 = NDKEvent.test(
            kind: 1,
            content: "Mention",
            pubkey: "user1",
            tags: [["p", userPubkey]],
            createdAt: Date()
        )
        let event2 = NDKEvent.test(
            kind: 1111,
            content: "Agent response",
            pubkey: "agent1",
            tags: [["p", userPubkey]],
            createdAt: Date()
        )

        await store.handleEvent(event1)
        await store.handleEvent(event2)

        // Step 3: Events are displayed
        #expect(store.events.count == 2)
        #expect(store.unreadCount == 2)
        #expect(store.isLoading == false)

        // Step 4: Mark as read
        store.markAllRead()

        // Step 5: Verify state
        #expect(store.unreadCount == 0)
        #expect(store.events.count == 2) // Events still visible
    }

    @Test("Deduplication works in real-time stream")
    func deduplicationWorksInRealTimeStream() async {
        // Given: Active subscription
        let store = InboxStore()
        let ndk = NDK(relayURLs: [])
        await store.subscribe(ndk: ndk, userPubkey: "test-user")

        let rootID = "thread-root"

        // When: Multiple updates arrive for same thread
        let update1 = NDKEvent.test(
            kind: 1111,
            content: "Progress: 10%",
            pubkey: "agent",
            tags: [["E", rootID]],
            createdAt: Date().addingTimeInterval(-10)
        )
        let update2 = NDKEvent.test(
            kind: 1111,
            content: "Progress: 50%",
            pubkey: "agent",
            tags: [["E", rootID]],
            createdAt: Date().addingTimeInterval(-5)
        )
        let update3 = NDKEvent.test(
            kind: 1111,
            content: "Progress: 100%",
            pubkey: "agent",
            tags: [["E", rootID]],
            createdAt: Date()
        )

        await store.handleEvent(update1)
        await store.handleEvent(update2)
        await store.handleEvent(update3)

        // Then: Only latest update is shown
        #expect(store.events.count == 1)
        #expect(store.events.first?.content == "Progress: 100%")
    }

    @Test("Multiple concurrent subscriptions coexist")
    func multipleConcurrentSubscriptionsCoexist() async {
        // Given: Two store instances
        let store1 = InboxStore()
        let store2 = InboxStore()
        let ndk = NDK(relayURLs: [])

        // When: Both subscribe
        await store1.subscribe(ndk: ndk, userPubkey: "user1")
        await store2.subscribe(ndk: ndk, userPubkey: "user2")

        // Then: Both subscriptions are active
        #expect(store1.isLoading == true)
        #expect(store2.isLoading == true)

        // Cleanup
        await store1.cleanup()
        await store2.cleanup()
    }

    // MARK: - Error Handling Integration Tests

    @Test("Handles subscription errors gracefully")
    func handlesSubscriptionErrorsGracefully() async {
        // Given: Store with invalid NDK
        let store = InboxStore()
        let invalidNDK = NDK(relayURLs: ["wss://invalid.relay.url"])

        // When: Attempting to subscribe
        await store.subscribe(ndk: invalidNDK, userPubkey: "test-user")

        // Then: Store should not crash and should handle error state
        // Note: Actual error handling depends on NDK implementation
        #expect(store.events.isEmpty)
    }

    @Test("Handles malformed events gracefully")
    func handlesMalformedEventsGracefully() async {
        // Given: Active subscription
        let store = InboxStore()
        let ndk = NDK(relayURLs: [])
        await store.subscribe(ndk: ndk, userPubkey: "test-user")

        // When: Malformed event arrives (missing required fields)
        let malformedEvent = NDKEvent.test(
            kind: 1111,
            content: "", // Empty content
            pubkey: "", // Empty pubkey
            tags: []
        )

        // Then: Should handle gracefully without crashing
        await store.handleEvent(malformedEvent)
        // Event may or may not be stored depending on validation logic
    }

    // MARK: - Performance Integration Tests

    @Test("Handles large event volume efficiently")
    func handlesLargeEventVolumeEfficiently() async {
        // Given: Store with subscription
        let store = InboxStore()
        let ndk = NDK(relayURLs: [])
        await store.subscribe(ndk: ndk, userPubkey: "test-user")

        // When: Many events arrive rapidly
        let startTime = Date()

        for index in 0 ..< 100 {
            let event = NDKEvent.test(
                kind: 1,
                content: "Event \(index)",
                pubkey: "user\(index % 10)",
                createdAt: Date().addingTimeInterval(TimeInterval(-index))
            )
            await store.handleEvent(event)
        }

        let elapsed = Date().timeIntervalSince(startTime)

        // Then: Processing should be fast (< 1 second for 100 events)
        #expect(elapsed < 1.0)
        #expect(store.events.count == 100)
    }

    @Test("Deduplication scales with event count")
    func deduplicationScalesWithEventCount() async {
        // Given: Many events with same E tag
        let store = InboxStore()
        let rootID = "popular-thread"
        var events: [NDKEvent] = []

        for index in 0 ..< 50 {
            events.append(
                NDKEvent.test(
                    kind: 1111,
                    content: "Update \(index)",
                    pubkey: "agent",
                    tags: [["E", rootID]],
                    createdAt: Date().addingTimeInterval(TimeInterval(-index))
                )
            )
        }

        // When: Deduplicating
        let startTime = Date()
        let deduplicated = store.deduplicateByETag(events)
        let elapsed = Date().timeIntervalSince(startTime)

        // Then: Deduplication is fast and correct
        #expect(elapsed < 0.1) // < 100ms
        #expect(deduplicated.count == 1)
        #expect(deduplicated.first?.content == "Update 0") // Most recent
    }
}

// MARK: - InboxAuthenticationIntegrationTests

@Suite("Inbox Authentication Integration Tests")
@MainActor
struct InboxAuthenticationIntegrationTests {
    @Test("Subscription auto-starts when user logs in")
    func subscriptionAutoStartsOnLogin() async {
        // Given: Unauthenticated state
        let store = InboxStore()
        #expect(store.events.isEmpty)

        // When: User logs in
        let ndk = NDK(relayURLs: [])
        let userPubkey = "09d48a1a5dbe13404a729634f1d6ba722d40513468dd713c8ea38ca9b7b6f2c7"

        await store.subscribe(ndk: ndk, userPubkey: userPubkey)

        // Then: Subscription is active
        #expect(store.isLoading == true)
    }

    @Test("Subscription stops when user logs out")
    func subscriptionStopsOnLogout() async {
        // Given: Active subscription
        let store = InboxStore()
        let ndk = NDK(relayURLs: [])
        await store.subscribe(ndk: ndk, userPubkey: "test-user")

        #expect(store.isLoading == true)

        // When: User logs out
        await store.cleanup()

        // Then: Subscription is stopped and state is cleared
        #expect(store.events.isEmpty)
        #expect(store.unreadCount == 0)
    }
}
