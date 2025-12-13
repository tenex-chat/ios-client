//
// FeedTabViewModelTests.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import NDKSwiftCore
import NDKSwiftTesting
@testable import TENEXCore
@testable import TENEXFeatures
import Testing

// MARK: - FeedTabViewModelTests

@Suite("FeedTabViewModel Tests")
struct FeedTabViewModelTests {
    // MARK: - Event Subscription Tests

    @Test("subscribes to events with project a-tag")
    @MainActor
    func subscribesToProjectEvents() async throws {
        // Given
        let ndk = NDK.mock()
        let projectID = "31933:pubkey123:project-id"
        let viewModel = FeedTabViewModel(ndk: ndk, projectID: projectID)

        // When
        Task {
            await viewModel.subscribe()
        }

        // Give subscription time to start
        try await Task.sleep(for: .milliseconds(100))

        // Then
        let subscriptions = await ndk.mockSubscriptionManager.activeSubscriptions
        #expect(subscriptions.count == 1)

        let filter = subscriptions.first?.filters.first
        #expect(filter?.tags?["a"] == [projectID])
    }

    @Test("deduplicates events by ID")
    @MainActor
    func deduplicatesEventsByID() async throws {
        // Given
        let ndk = NDK.mock()
        let projectID = "31933:pubkey123:project-id"
        let viewModel = FeedTabViewModel(ndk: ndk, projectID: projectID)

        // Create a test event
        let event1 = try NDKEvent(kind: 1111, content: "Test message")
        event1.id = "event-id-1"
        event1.tags.append(["a", projectID])

        // Same ID, different content
        let event2 = try NDKEvent(kind: 1111, content: "Different content")
        event2.id = "event-id-1" // Same ID
        event2.tags.append(["a", projectID])

        // When
        Task {
            await viewModel.subscribe()
        }

        // Give subscription time to start
        try await Task.sleep(for: .milliseconds(100))

        // Simulate receiving events
        await ndk.mockSubscriptionManager.publishEvent(event1)
        try await Task.sleep(for: .milliseconds(50))
        await ndk.mockSubscriptionManager.publishEvent(event2)
        try await Task.sleep(for: .milliseconds(50))

        // Then
        #expect(viewModel.events.count == 1)
        #expect(viewModel.events.first?.id == "event-id-1")
    }

    // MARK: - Event Filtering Tests

    @Test("filters out kind 0 (metadata)")
    @MainActor
    func filtersOutKind0() async throws {
        // Given
        let ndk = NDK.mock()
        let projectID = "31933:pubkey123:project-id"
        let viewModel = FeedTabViewModel(ndk: ndk, projectID: projectID)

        // Create kind 0 event (metadata)
        let metadataEvent = try NDKEvent(kind: 0, content: "{\"name\":\"test\"}")
        metadataEvent.id = "metadata-1"
        metadataEvent.tags.append(["a", projectID])

        // Create normal event
        let normalEvent = try NDKEvent(kind: 1111, content: "Test message")
        normalEvent.id = "normal-1"
        normalEvent.tags.append(["a", projectID])

        // When
        Task {
            await viewModel.subscribe()
        }

        try await Task.sleep(for: .milliseconds(100))

        await ndk.mockSubscriptionManager.publishEvent(metadataEvent)
        try await Task.sleep(for: .milliseconds(50))
        await ndk.mockSubscriptionManager.publishEvent(normalEvent)
        try await Task.sleep(for: .milliseconds(50))

        // Then
        #expect(viewModel.events.count == 1)
        #expect(viewModel.events.first?.kind == 1111)
    }

    @Test("filters out ephemeral events (20000-29999)")
    @MainActor
    func filtersOutEphemeralEvents() async throws {
        // Given
        let ndk = NDK.mock()
        let projectID = "31933:pubkey123:project-id"
        let viewModel = FeedTabViewModel(ndk: ndk, projectID: projectID)

        // Create ephemeral event (kind 20000)
        let ephemeralEvent = try NDKEvent(kind: 20_000, content: "Ephemeral")
        ephemeralEvent.id = "ephemeral-1"
        ephemeralEvent.tags.append(["a", projectID])

        // Create another ephemeral (kind 25000)
        let ephemeralEvent2 = try NDKEvent(kind: 25_000, content: "Ephemeral 2")
        ephemeralEvent2.id = "ephemeral-2"
        ephemeralEvent2.tags.append(["a", projectID])

        // Create normal event
        let normalEvent = try NDKEvent(kind: 1111, content: "Normal message")
        normalEvent.id = "normal-1"
        normalEvent.tags.append(["a", projectID])

        // When
        Task {
            await viewModel.subscribe()
        }

        try await Task.sleep(for: .milliseconds(100))

        await ndk.mockSubscriptionManager.publishEvent(ephemeralEvent)
        try await Task.sleep(for: .milliseconds(50))
        await ndk.mockSubscriptionManager.publishEvent(ephemeralEvent2)
        try await Task.sleep(for: .milliseconds(50))
        await ndk.mockSubscriptionManager.publishEvent(normalEvent)
        try await Task.sleep(for: .milliseconds(50))

        // Then
        #expect(viewModel.events.count == 1)
        #expect(viewModel.events.first?.kind == 1111)
    }

    @Test("includes valid event kinds")
    @MainActor
    func includesValidEvents() async throws {
        // Given
        let ndk = NDK.mock()
        let projectID = "31933:pubkey123:project-id"
        let viewModel = FeedTabViewModel(ndk: ndk, projectID: projectID)

        // Create various valid events
        let thread = try NDKEvent(kind: 11, content: "Thread")
        thread.id = "thread-1"
        thread.tags.append(["a", projectID])

        let message = try NDKEvent(kind: 1111, content: "Message")
        message.id = "message-1"
        message.tags.append(["a", projectID])

        let article = try NDKEvent(kind: 30_023, content: "Article")
        article.id = "article-1"
        article.tags.append(["a", projectID])

        // When
        Task {
            await viewModel.subscribe()
        }

        try await Task.sleep(for: .milliseconds(100))

        await ndk.mockSubscriptionManager.publishEvent(thread)
        try await Task.sleep(for: .milliseconds(50))
        await ndk.mockSubscriptionManager.publishEvent(message)
        try await Task.sleep(for: .milliseconds(50))
        await ndk.mockSubscriptionManager.publishEvent(article)
        try await Task.sleep(for: .milliseconds(50))

        // Then
        #expect(viewModel.events.count == 3)
        #expect(viewModel.events.contains { $0.kind == 11 })
        #expect(viewModel.events.contains { $0.kind == 1111 })
        #expect(viewModel.events.contains { $0.kind == 30_023 })
    }

    // MARK: - Search Tests

    @Test("search matches event content")
    @MainActor
    func searchMatchesContent() throws {
        // Given
        let ndk = NDK.mock()
        let viewModel = FeedTabViewModel(ndk: ndk, projectID: "test-project")

        let event1 = try NDKEvent(kind: 1111, content: "Hello world")
        event1.id = "1"
        let event2 = try NDKEvent(kind: 1111, content: "Goodbye")
        event2.id = "2"

        viewModel.events = [event1, event2]

        // When
        viewModel.searchQuery = "hello"

        // Then
        #expect(viewModel.filteredEvents.count == 1)
        #expect(viewModel.filteredEvents.first?.content == "Hello world")
    }

    @Test("search matches article titles")
    @MainActor
    func searchMatchesArticleTitles() throws {
        // Given
        let ndk = NDK.mock()
        let viewModel = FeedTabViewModel(ndk: ndk, projectID: "test-project")

        let article = try NDKEvent(kind: 30_023, content: "Article content")
        article.id = "1"
        article.tags.append(["title", "Swift Programming"])

        let message = try NDKEvent(kind: 1111, content: "Regular message")
        message.id = "2"

        viewModel.events = [article, message]

        // When
        viewModel.searchQuery = "swift"

        // Then
        #expect(viewModel.filteredEvents.count == 1)
        #expect(viewModel.filteredEvents.first?.kind == 30_023)
    }

    @Test("search matches hashtags")
    @MainActor
    func searchMatchesHashtags() throws {
        // Given
        let ndk = NDK.mock()
        let viewModel = FeedTabViewModel(ndk: ndk, projectID: "test-project")

        let event1 = try NDKEvent(kind: 1111, content: "Message")
        event1.id = "1"
        event1.tags.append(["t", "nostr"])

        let event2 = try NDKEvent(kind: 1111, content: "Another message")
        event2.id = "2"
        event2.tags.append(["t", "bitcoin"])

        viewModel.events = [event1, event2]

        // When
        viewModel.searchQuery = "nostr"

        // Then
        #expect(viewModel.filteredEvents.count == 1)
        #expect(viewModel.filteredEvents.first?.tags.contains(["t", "nostr"]) == true)
    }

    @Test("search is case insensitive")
    @MainActor
    func searchCaseInsensitive() throws {
        // Given
        let ndk = NDK.mock()
        let viewModel = FeedTabViewModel(ndk: ndk, projectID: "test-project")

        let event = try NDKEvent(kind: 1111, content: "Hello WORLD")
        event.id = "1"

        viewModel.events = [event]

        // When
        viewModel.searchQuery = "HELLO"

        // Then
        #expect(viewModel.filteredEvents.count == 1)
    }

    // MARK: - Author Filtering Tests

    @Test("filters events by selected author")
    @MainActor
    func filtersByAuthor() throws {
        // Given
        let ndk = NDK.mock()
        let viewModel = FeedTabViewModel(ndk: ndk, projectID: "test-project")

        let event1 = try NDKEvent(kind: 1111, content: "From Alice")
        event1.id = "1"
        event1.pubkey = "alice-pubkey"

        let event2 = try NDKEvent(kind: 1111, content: "From Bob")
        event2.id = "2"
        event2.pubkey = "bob-pubkey"

        viewModel.events = [event1, event2]

        // When
        viewModel.selectedAuthor = "alice-pubkey"

        // Then
        #expect(viewModel.filteredEvents.count == 1)
        #expect(viewModel.filteredEvents.first?.pubkey == "alice-pubkey")
    }

    @Test("unique authors limited to 15")
    @MainActor
    func uniqueAuthorsLimitedTo15() throws {
        // Given
        let ndk = NDK.mock()
        let viewModel = FeedTabViewModel(ndk: ndk, projectID: "test-project")

        // Create 20 events from different authors
        var events: [NDKEvent] = []
        for index in 0 ..< 20 {
            let event = try NDKEvent(kind: 1111, content: "Message \(index)")
            event.id = "event-\(index)"
            event.pubkey = "pubkey-\(index)"
            events.append(event)
        }

        viewModel.events = events

        // Then
        #expect(viewModel.uniqueAuthors.count == 15)
    }

    // MARK: - Thread Grouping Tests

    @Test("thread grouping keeps most recent per E tag")
    @MainActor
    func threadGroupingKeepsMostRecent() throws {
        // Given
        let ndk = NDK.mock()
        let viewModel = FeedTabViewModel(ndk: ndk, projectID: "test-project")

        let event1 = try NDKEvent(kind: 1111, content: "First reply")
        event1.id = "1"
        event1.createdAt = 1000
        event1.tags.append(["E", "thread-123"])

        let event2 = try NDKEvent(kind: 1111, content: "Second reply")
        event2.id = "2"
        event2.createdAt = 2000
        event2.tags.append(["E", "thread-123"])

        let event3 = try NDKEvent(kind: 1111, content: "Third reply")
        event3.id = "3"
        event3.createdAt = 3000
        event3.tags.append(["E", "thread-123"])

        viewModel.events = [event1, event2, event3]

        // When
        viewModel.groupThreads = true

        // Then
        #expect(viewModel.filteredEvents.count == 1)
        #expect(viewModel.filteredEvents.first?.id == "3")
    }

    @Test("thread grouping preserves events without E tag")
    @MainActor
    func threadGroupingPreservesNoETag() throws {
        // Given
        let ndk = NDK.mock()
        let viewModel = FeedTabViewModel(ndk: ndk, projectID: "test-project")

        let thread1 = try NDKEvent(kind: 1111, content: "Thread reply")
        thread1.id = "1"
        thread1.tags.append(["E", "thread-123"])

        let standalone = try NDKEvent(kind: 11, content: "Standalone thread")
        standalone.id = "2"

        viewModel.events = [thread1, standalone]

        // When
        viewModel.groupThreads = true

        // Then
        #expect(viewModel.filteredEvents.count == 2)
    }
}
