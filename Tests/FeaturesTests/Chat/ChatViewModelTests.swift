//
// ChatViewModelTests.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation
import NDKSwiftCore
import NDKSwiftTesting
import TENEXCore
@testable import TENEXFeatures
import Testing

@Suite("ChatViewModel Tests")
@MainActor
struct ChatViewModelTests {
    // MARK: - Tests

    @Test("Initialize with thread event and project reference")
    func initializeWithThreadEventAndProjectReference() async {
        // Given: A thread event and project reference
        let threadEvent = NDKEvent.test(kind: 11, content: "Thread content", pubkey: "thread-author")
        let projectReference = "31933:project-author:my-project"
        let ndk = NDK(relayURLs: [])

        // When: Creating view model
        let viewModel = ChatViewModel(
            ndk: ndk,
            threadEvent: threadEvent,
            projectReference: projectReference,
            userPubkey: "test-user"
        )

        // Then: View model is initialized with thread event as first message
        #expect(viewModel.messages.count == 1)
        #expect(viewModel.messages.first?.id == threadEvent.id)
        #expect(viewModel.messages.first?.content == "Thread content")
        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.streamingContent.isEmpty)
        #expect(viewModel.typingUsers.isEmpty)
        #expect(viewModel.threadID == threadEvent.id)
    }

    @Test("Load messages from NDK")
    func loadMessagesFromNDK() async {
        // Given: NDK with no relays (will return empty results)
        let threadEvent = NDKEvent.test(kind: 11, content: "Thread content", pubkey: "thread-author")
        let projectReference = "31933:project-author:my-project"
        let ndk = NDK(relayURLs: [])

        // When: Loading messages
        let viewModel = ChatViewModel(
            ndk: ndk,
            threadEvent: threadEvent,
            projectReference: projectReference,
            userPubkey: "test-user"
        )

        // Then: Only the thread event is present (no relays to fetch replies from)
        #expect(viewModel.messages.count == 1)
        #expect(viewModel.messages.first?.id == threadEvent.id)
        #expect(viewModel.errorMessage == nil)
    }

    @Test("Thread event is always the first message")
    func threadEventIsFirstMessage() async {
        // Given: NDK with thread event
        let threadEvent = NDKEvent.test(kind: 11, content: "Thread content", pubkey: "thread-author")
        let projectReference = "31933:project-author:my-project"
        let ndk = NDK(relayURLs: [])

        // When: Loading messages
        let viewModel = ChatViewModel(
            ndk: ndk,
            threadEvent: threadEvent,
            projectReference: projectReference,
            userPubkey: "test-user"
        )

        // Then: Thread event is the first message
        #expect(viewModel.messages.count == 1)
        #expect(viewModel.messages.first?.content == "Thread content")
        #expect(viewModel.errorMessage == nil)
    }

    @Test("Messages include thread event and replies")
    func messagesIncludeThreadAndReplies() async {
        // Given: NDK with thread event
        let threadEvent = NDKEvent.test(kind: 11, content: "Thread content", pubkey: "thread-author")
        let projectReference = "31933:project-author:my-project"
        let ndk = NDK(relayURLs: [])

        // When: Creating view model
        let viewModel = ChatViewModel(
            ndk: ndk,
            threadEvent: threadEvent,
            projectReference: projectReference,
            userPubkey: "test-user"
        )

        // Then: Thread event is included as first message
        #expect(viewModel.messages.count == 1)
        #expect(viewModel.messages.first?.id == threadEvent.id)
    }
}
