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

        // Then: View model is initialized with empty state
        #expect(viewModel.messages.isEmpty)
        #expect(viewModel.isLoading == false)
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
        await viewModel.loadMessages()

        // Then: No messages are loaded (no relays to fetch from)
        #expect(viewModel.messages.isEmpty)
        #expect(viewModel.isLoading == false)
        #expect(viewModel.errorMessage == nil)
    }

    @Test("Handle empty messages list")
    func handleEmptyMessagesList() async {
        // Given: NDK with no messages
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
        await viewModel.loadMessages()

        // Then: Messages list is empty
        #expect(viewModel.messages.isEmpty)
        #expect(viewModel.isLoading == false)
        #expect(viewModel.errorMessage == nil)
    }

    @Test("Refresh reloads messages")
    func refreshReloadsMessages() async {
        // Given: NDK with messages
        let threadEvent = NDKEvent.test(kind: 11, content: "Thread content", pubkey: "thread-author")
        let projectReference = "31933:project-author:my-project"
        let ndk = NDK(relayURLs: [])

        // When: Refreshing
        let viewModel = ChatViewModel(
            ndk: ndk,
            threadEvent: threadEvent,
            projectReference: projectReference,
            userPubkey: "test-user"
        )
        await viewModel.refresh()

        // Then: Messages are loaded (empty in this case)
        #expect(viewModel.messages.isEmpty)
    }
}
