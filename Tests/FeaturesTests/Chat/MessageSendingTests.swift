//
// MessageSendingTests.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation
import NDKSwiftCore
import NDKSwiftTesting
import TENEXCore
@testable import TENEXFeatures
import Testing

@Suite("Message Sending Tests")
@MainActor
struct MessageSendingTests {
    // MARK: - Tests

    @Test("Send message creates kind 1111 event")
    func sendMessageCreatesCorrectKind() async {
        // Given: A chat view model with mock NDK
        let threadEvent = NDKEvent.test(kind: 11, content: "Thread content", pubkey: "thread-author")
        let projectReference = "31933:project-author:my-project"
        let mockNDK = MockNDK()
        let viewModel = ChatViewModel(
            ndk: mockNDK,
            threadEvent: threadEvent,
            projectReference: projectReference,
            userPubkey: "test-user"
        )

        // When: Sending a message
        await viewModel.sendMessage(text: "Hello, world!")

        // Then: NDK published an event with kind 1111
        #expect(mockNDK.publishedEvents.count == 1)
        let event = mockNDK.publishedEvents[0]
        #expect(event.kind == 1111)
        #expect(event.content == "Hello, world!")
    }

    @Test("Send message adds project reference tag")
    func sendMessageAddsProjectTag() async {
        // Given: A chat view model
        let threadEvent = NDKEvent.test(kind: 11, content: "Thread content", pubkey: "thread-author")
        let projectReference = "31933:project-author:my-project"
        let mockNDK = MockNDK()
        let viewModel = ChatViewModel(
            ndk: mockNDK,
            threadEvent: threadEvent,
            projectReference: projectReference,
            userPubkey: "test-user"
        )

        // When: Sending a message
        await viewModel.sendMessage(text: "Test message")

        // Then: Event has 'a' tag referencing the PROJECT (not the thread)
        let event = mockNDK.publishedEvents[0]
        let aTags = event.tags(withName: "a")
        #expect(aTags.count == 1)
        #expect(aTags[0].count > 1)
        #expect(aTags[0][1] == projectReference)
    }

    @Test("Send message adds thread event reference via e-tag")
    func sendMessageAddsThreadReference() async {
        // Given: A chat view model
        let threadEvent = NDKEvent.test(kind: 11, content: "Thread content", pubkey: "thread-author")
        let projectReference = "31933:project-author:my-project"
        let mockNDK = MockNDK()
        let viewModel = ChatViewModel(
            ndk: mockNDK,
            threadEvent: threadEvent,
            projectReference: projectReference,
            userPubkey: "test-user"
        )

        // When: Sending a message
        await viewModel.sendMessage(text: "Test message")

        // Then: Event has 'e' tag referencing the thread event (added by publishReply)
        let event = mockNDK.publishedEvents[0]
        let eTags = event.tags(withName: "e")
        #expect(eTags.count >= 1)
        #expect(eTags.first?[safe: 1] == threadEvent.id)
    }

    @Test("Send reply adds parent message reference with reply marker")
    func sendReplyAddsParentTag() async {
        // Given: A chat view model with an existing message
        let threadEvent = NDKEvent.test(kind: 11, content: "Thread content", pubkey: "thread-author")
        let projectReference = "31933:project-author:my-project"
        let mockNDK = MockNDK()
        let viewModel = ChatViewModel(
            ndk: mockNDK,
            threadEvent: threadEvent,
            projectReference: projectReference,
            userPubkey: "test-user"
        )

        let parentMessage = Message(
            id: "parent-msg-id",
            pubkey: "user1",
            threadID: projectReference,
            content: "Parent message",
            createdAt: Date(),
            replyTo: nil,
            status: nil
        )

        // When: Sending a reply
        await viewModel.sendMessage(text: "Reply message", replyTo: parentMessage)

        // Then: Event has 'e' tag referencing the parent message with 'reply' marker
        let event = mockNDK.publishedEvents[0]
        let eTags = event.tags(withName: "e")
        let parentTag = eTags.first { $0[safe: 1] == "parent-msg-id" }
        #expect(parentTag != nil)
        #expect(parentTag?[safe: 3] == "reply")
    }

    @Test("Send reply adds p-tag for parent author")
    func sendReplyAddsPTagForParentAuthor() async {
        // Given: A chat view model with an existing message
        let threadEvent = NDKEvent.test(kind: 11, content: "Thread content", pubkey: "thread-author")
        let projectReference = "31933:project-author:my-project"
        let mockNDK = MockNDK()
        let viewModel = ChatViewModel(
            ndk: mockNDK,
            threadEvent: threadEvent,
            projectReference: projectReference,
            userPubkey: "test-user"
        )

        let parentMessage = Message(
            id: "parent-msg-id",
            pubkey: "original-author-pubkey",
            threadID: projectReference,
            content: "Parent message",
            createdAt: Date(),
            replyTo: nil,
            status: nil
        )

        // When: Sending a reply
        await viewModel.sendMessage(text: "Reply message", replyTo: parentMessage)

        // Then: Event has 'p' tag for the parent message author
        let event = mockNDK.publishedEvents[0]
        let pTags = event.tags(withName: "p")
        let authorTag = pTags.first { $0[safe: 1] == "original-author-pubkey" }
        #expect(authorTag != nil)
    }

    @Test("Send message shows optimistic update immediately")
    func sendMessageShowsOptimisticUpdate() async {
        // Given: A chat view model with delayed publish
        let threadEvent = NDKEvent.test(kind: 11, content: "Thread content", pubkey: "thread-author")
        let projectReference = "31933:project-author:my-project"
        let mockNDK = MockNDK()
        mockNDK.publishDelay = 0.1 // Add delay to observe sending state
        let viewModel = ChatViewModel(
            ndk: mockNDK,
            threadEvent: threadEvent,
            projectReference: projectReference,
            userPubkey: "test-user"
        )

        // When: Sending a message (without await to capture intermediate state)
        Task {
            await viewModel.sendMessage(text: "Optimistic message")
        }

        // Brief wait to let optimistic message be added
        try? await Task.sleep(nanoseconds: 10_000_000) // 0.01 seconds

        // Then: Message is added with sending status
        #expect(viewModel.messages.count == 1)
        #expect(viewModel.messages[0].content == "Optimistic message")
        #expect(viewModel.messages[0].status == .sending)

        // Wait for publish to complete
        try? await Task.sleep(nanoseconds: 150_000_000) // 0.15 seconds

        // Finally: Message is marked as sent
        #expect(viewModel.messages[0].status == .sent)
    }

    @Test("Send message updates status to sent after publish")
    func sendMessageUpdatesStatusAfterPublish() async {
        // Given: A chat view model
        let threadEvent = NDKEvent.test(kind: 11, content: "Thread content", pubkey: "thread-author")
        let projectReference = "31933:project-author:my-project"
        let mockNDK = MockNDK()
        mockNDK.publishDelay = 0.1 // Simulate network delay
        let viewModel = ChatViewModel(
            ndk: mockNDK,
            threadEvent: threadEvent,
            projectReference: projectReference,
            userPubkey: "test-user"
        )

        // When: Sending a message
        await viewModel.sendMessage(text: "Test message")

        // Then: Message status is updated to sent
        #expect(viewModel.messages.count == 1)
        #expect(viewModel.messages[0].status == .sent)
    }

    @Test("Send message updates with event ID after publish")
    func sendMessageUpdatesEventID() async {
        // Given: A chat view model
        let threadEvent = NDKEvent.test(kind: 11, content: "Thread content", pubkey: "thread-author")
        let projectReference = "31933:project-author:my-project"
        let mockNDK = MockNDK()
        let viewModel = ChatViewModel(
            ndk: mockNDK,
            threadEvent: threadEvent,
            projectReference: projectReference,
            userPubkey: "test-user"
        )

        // When: Sending a message
        await viewModel.sendMessage(text: "Test message")

        // Then: Message has the event ID from the published event
        #expect(viewModel.messages.count == 1)
        let message = viewModel.messages[0]
        #expect(message.id == mockNDK.publishedEvents[0].id)
    }

    @Test("Failed send shows error status")
    func failedSendShowsErrorStatus() async {
        // Given: A mock NDK that fails to publish
        let threadEvent = NDKEvent.test(kind: 11, content: "Thread content", pubkey: "thread-author")
        let projectReference = "31933:project-author:my-project"
        let mockNDK = MockNDK()
        mockNDK.publishShouldFail = true
        let viewModel = ChatViewModel(
            ndk: mockNDK,
            threadEvent: threadEvent,
            projectReference: projectReference,
            userPubkey: "test-user"
        )

        // When: Attempting to send a message
        await viewModel.sendMessage(text: "Failed message")

        // Then: Message status is failed
        #expect(viewModel.messages.count == 1)
        if case .failed = viewModel.messages[0].status {
            // Success
        } else {
            Issue.record("Expected message to have failed status")
        }
    }

    @Test("Retry failed message")
    func retryFailedMessage() async {
        // Given: A view model with a failed message
        let threadEvent = NDKEvent.test(kind: 11, content: "Thread content", pubkey: "thread-author")
        let projectReference = "31933:project-author:my-project"
        let mockNDK = MockNDK()
        mockNDK.publishShouldFail = true
        let viewModel = ChatViewModel(
            ndk: mockNDK,
            threadEvent: threadEvent,
            projectReference: projectReference,
            userPubkey: "test-user"
        )

        await viewModel.sendMessage(text: "Failed message")
        guard case .failed = viewModel.messages[0].status else {
            Issue.record("Expected message to have failed status")
            return
        }

        // When: Retrying the message
        mockNDK.publishShouldFail = false
        let failedMessage = viewModel.messages[0]
        await viewModel.retrySendMessage(failedMessage)

        // Then: Message is resent successfully
        #expect(viewModel.messages[0].status == .sent)
        #expect(mockNDK.publishedEvents.count == 1) // Only retry succeeded (original failed before publishing)
    }

    @Test("Multiple messages maintain correct order")
    func multipleMessagesMaintainOrder() async {
        // Given: A chat view model
        let threadEvent = NDKEvent.test(kind: 11, content: "Thread content", pubkey: "thread-author")
        let projectReference = "31933:project-author:my-project"
        let mockNDK = MockNDK()
        let viewModel = ChatViewModel(
            ndk: mockNDK,
            threadEvent: threadEvent,
            projectReference: projectReference,
            userPubkey: "test-user"
        )

        // When: Sending multiple messages
        await viewModel.sendMessage(text: "First")
        await viewModel.sendMessage(text: "Second")
        await viewModel.sendMessage(text: "Third")

        // Then: Messages are in the correct order
        #expect(viewModel.messages.count == 3)
        #expect(viewModel.messages[0].content == "First")
        #expect(viewModel.messages[1].content == "Second")
        #expect(viewModel.messages[2].content == "Third")
    }

    @Test("Send empty message is rejected")
    func sendEmptyMessageRejected() async {
        // Given: A chat view model
        let threadEvent = NDKEvent.test(kind: 11, content: "Thread content", pubkey: "thread-author")
        let projectReference = "31933:project-author:my-project"
        let mockNDK = MockNDK()
        let viewModel = ChatViewModel(
            ndk: mockNDK,
            threadEvent: threadEvent,
            projectReference: projectReference,
            userPubkey: "test-user"
        )

        // When: Attempting to send an empty message
        await viewModel.sendMessage(text: "")

        // Then: No message is sent
        #expect(viewModel.messages.isEmpty)
        #expect(mockNDK.publishedEvents.isEmpty)
    }

    @Test("Send whitespace-only message is rejected")
    func sendWhitespaceMessageRejected() async {
        // Given: A chat view model
        let threadEvent = NDKEvent.test(kind: 11, content: "Thread content", pubkey: "thread-author")
        let projectReference = "31933:project-author:my-project"
        let mockNDK = MockNDK()
        let viewModel = ChatViewModel(
            ndk: mockNDK,
            threadEvent: threadEvent,
            projectReference: projectReference,
            userPubkey: "test-user"
        )

        // When: Attempting to send a whitespace-only message
        await viewModel.sendMessage(text: "   \n\t  ")

        // Then: No message is sent
        #expect(viewModel.messages.isEmpty)
        #expect(mockNDK.publishedEvents.isEmpty)
    }
}
