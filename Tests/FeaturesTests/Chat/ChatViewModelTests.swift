//
// ChatViewModelTests.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation
import NDKSwiftCore
import TENEXCore
@testable import TENEXFeatures
import Testing

@Suite("ChatViewModel Tests")
@MainActor
struct ChatViewModelTests {
    @Test("Initialize with thread ID")
    func initializeWithThreadID() async {
        // Given: A thread ID and mock NDK
        let threadID = "11:pubkey:my-thread"
        let mockNDK = MockNDK()

        // When: Creating view model
        let viewModel = ChatViewModel(ndk: mockNDK, threadID: threadID, userPubkey: "test-user")

        // Then: View model is initialized with empty state
        #expect(viewModel.messages.isEmpty)
        #expect(viewModel.isLoading == false)
        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.streamingContent.isEmpty)
        #expect(viewModel.typingUsers.isEmpty)
    }

    @Test("Load messages from NDK")
    func loadMessagesFromNDK() async {
        // Given: Mock NDK with message events
        let threadID = "11:pubkey:my-thread"
        let mockNDK = MockNDK()

        let event1 = NDKEvent(
            pubkey: "user1",
            createdAt: 1000,
            kind: 1111,
            tags: [["a", threadID]],
            content: "First message"
        )

        let event2 = NDKEvent(
            pubkey: "user2",
            createdAt: 2000,
            kind: 1111,
            tags: [["a", threadID]],
            content: "Second message"
        )

        mockNDK.mockEvents = [event1, event2]

        // When: Loading messages
        let viewModel = ChatViewModel(ndk: mockNDK, threadID: threadID, userPubkey: "test-user")
        await viewModel.loadMessages()

        // Then: Messages are loaded and sorted by creation date
        #expect(viewModel.messages.count == 2)
        #expect(viewModel.messages[0].content == "First message")
        #expect(viewModel.messages[1].content == "Second message")
        #expect(viewModel.isLoading == false)
        #expect(viewModel.errorMessage == nil)
    }

    @Test("Sort messages by creation date (oldest first)")
    func sortMessagesByCreationDate() async {
        // Given: Mock NDK with unsorted message events
        let threadID = "11:pubkey:my-thread"
        let mockNDK = MockNDK()

        let event1 = NDKEvent(
            pubkey: "user1",
            createdAt: 2000, // Newer
            kind: 1111,
            tags: [["a", threadID]],
            content: "Second message"
        )

        let event2 = NDKEvent(
            pubkey: "user2",
            createdAt: 1000, // Older
            kind: 1111,
            tags: [["a", threadID]],
            content: "First message"
        )

        mockNDK.mockEvents = [event1, event2]

        // When: Loading messages
        let viewModel = ChatViewModel(ndk: mockNDK, threadID: threadID, userPubkey: "test-user")
        await viewModel.loadMessages()

        // Then: Messages are sorted oldest first
        #expect(viewModel.messages[0].content == "First message")
        #expect(viewModel.messages[1].content == "Second message")
    }

    @Test("Handle empty messages list")
    func handleEmptyMessagesList() async {
        // Given: Mock NDK with no messages
        let threadID = "11:pubkey:my-thread"
        let mockNDK = MockNDK()
        mockNDK.mockEvents = []

        // When: Loading messages
        let viewModel = ChatViewModel(ndk: mockNDK, threadID: threadID, userPubkey: "test-user")
        await viewModel.loadMessages()

        // Then: Messages list is empty
        #expect(viewModel.messages.isEmpty)
        #expect(viewModel.isLoading == false)
        #expect(viewModel.errorMessage == nil)
    }

    @Test("Handle invalid message events")
    func handleInvalidMessageEvents() async {
        // Given: Mock NDK with invalid events (wrong kind)
        let threadID = "11:pubkey:my-thread"
        let mockNDK = MockNDK()

        let invalidEvent = NDKEvent(
            pubkey: "user1",
            kind: 1, // Wrong kind
            tags: [["a", threadID]],
            content: "Invalid message"
        )

        mockNDK.mockEvents = [invalidEvent]

        // When: Loading messages
        let viewModel = ChatViewModel(ndk: mockNDK, threadID: threadID, userPubkey: "test-user")
        await viewModel.loadMessages()

        // Then: Invalid events are filtered out
        #expect(viewModel.messages.isEmpty)
    }

    @Test("Handle error during message loading")
    func handleErrorDuringLoading() async {
        // Given: Mock NDK that throws an error
        let threadID = "11:pubkey:my-thread"
        let mockNDK = MockNDK()
        mockNDK.shouldThrowError = true

        // When: Loading messages
        let viewModel = ChatViewModel(ndk: mockNDK, threadID: threadID, userPubkey: "test-user")
        await viewModel.loadMessages()

        // Then: Error message is set
        #expect(viewModel.errorMessage != nil)
        #expect(viewModel.messages.isEmpty)
        #expect(viewModel.isLoading == false)
    }

    @Test("Subscribe to streaming deltas")
    func subscribeToStreamingDeltas() async {
        // Given: Mock NDK with streaming delta events
        let threadID = "11:pubkey:my-thread"
        let messageID = "msg-1"
        let mockNDK = MockNDK()

        let delta1 = NDKEvent(
            pubkey: "agent1",
            kind: 21_111,
            tags: [["e", messageID]],
            content: "Hello "
        )

        let delta2 = NDKEvent(
            pubkey: "agent1",
            kind: 21_111,
            tags: [["e", messageID]],
            content: "world!"
        )

        mockNDK.mockEvents = [delta1, delta2]

        // When: Subscribing to streaming deltas
        let viewModel = ChatViewModel(ndk: mockNDK, threadID: threadID, userPubkey: "test-user")
        await viewModel.subscribeToStreamingDeltas()

        // Then: Deltas are accumulated
        #expect(viewModel.streamingContent[messageID] == "Hello world!")
    }

    @Test("Subscribe to typing indicators (user typing)")
    func subscribeToUserTypingIndicators() async {
        // Given: Mock NDK with typing indicator events
        let threadID = "11:pubkey:my-thread"
        let mockNDK = MockNDK()

        let typingEvent = NDKEvent(
            pubkey: "user1",
            kind: 24_111,
            tags: [["e", threadID]],
            content: ""
        )

        mockNDK.mockEvents = [typingEvent]

        // When: Subscribing to typing indicators
        let viewModel = ChatViewModel(ndk: mockNDK, threadID: threadID, userPubkey: "test-user")
        await viewModel.subscribeToTypingIndicators()

        // Then: Typing user is tracked
        #expect(viewModel.typingUsers.contains("user1"))
    }

    @Test("Subscribe to typing indicators (agent typing)")
    func subscribeToAgentTypingIndicators() async {
        // Given: Mock NDK with agent typing indicator events
        let threadID = "11:pubkey:my-thread"
        let mockNDK = MockNDK()

        let agentTypingEvent = NDKEvent(
            pubkey: "agent1",
            kind: 24_112,
            tags: [["e", threadID]],
            content: ""
        )

        mockNDK.mockEvents = [agentTypingEvent]

        // When: Subscribing to typing indicators
        let viewModel = ChatViewModel(ndk: mockNDK, threadID: threadID, userPubkey: "test-user")
        await viewModel.subscribeToTypingIndicators()

        // Then: Agent typing is tracked
        #expect(viewModel.typingUsers.contains("agent1"))
    }

    @Test("Refresh reloads messages")
    func refreshReloadsMessages() async {
        // Given: Mock NDK with messages
        let threadID = "11:pubkey:my-thread"
        let mockNDK = MockNDK()

        let event = NDKEvent(
            pubkey: "user1",
            createdAt: 1000,
            kind: 1111,
            tags: [["a", threadID]],
            content: "Test message"
        )

        mockNDK.mockEvents = [event]

        // When: Refreshing
        let viewModel = ChatViewModel(ndk: mockNDK, threadID: threadID, userPubkey: "test-user")
        await viewModel.refresh()

        // Then: Messages are loaded
        #expect(viewModel.messages.count == 1)
        #expect(viewModel.messages[0].content == "Test message")
    }

    @Test("Clear error message on reload")
    func clearErrorMessageOnReload() async {
        // Given: View model with an error
        let threadID = "11:pubkey:my-thread"
        let mockNDK = MockNDK()
        mockNDK.shouldThrowError = true

        let viewModel = ChatViewModel(ndk: mockNDK, threadID: threadID, userPubkey: "test-user")
        await viewModel.loadMessages()

        #expect(viewModel.errorMessage != nil)

        // When: Reloading with success
        mockNDK.shouldThrowError = false
        mockNDK.mockEvents = []
        await viewModel.loadMessages()

        // Then: Error message is cleared
        #expect(viewModel.errorMessage == nil)
    }
}
