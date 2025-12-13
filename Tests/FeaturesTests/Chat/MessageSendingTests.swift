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

    @Test("Send empty message is rejected")
    func sendEmptyMessageRejected() async {
        // Given: A chat view model
        let threadEvent = NDKEvent.test(kind: 11, content: "Thread content", pubkey: "thread-author")
        let projectReference = "31933:project-author:my-project"
        let ndk = NDK(relayURLs: [])
        let viewModel = ChatViewModel(
            ndk: ndk,
            threadEvent: threadEvent,
            projectReference: projectReference,
            userPubkey: "test-user"
        )

        // When: Attempting to send an empty message
        await viewModel.sendMessage(text: "")

        // Then: No message is sent
        #expect(viewModel.messages.isEmpty)
    }

    @Test("Send whitespace-only message is rejected")
    func sendWhitespaceMessageRejected() async {
        // Given: A chat view model
        let threadEvent = NDKEvent.test(kind: 11, content: "Thread content", pubkey: "thread-author")
        let projectReference = "31933:project-author:my-project"
        let ndk = NDK(relayURLs: [])
        let viewModel = ChatViewModel(
            ndk: ndk,
            threadEvent: threadEvent,
            projectReference: projectReference,
            userPubkey: "test-user"
        )

        // When: Attempting to send a whitespace-only message
        await viewModel.sendMessage(text: "   \n\t  ")

        // Then: No message is sent
        #expect(viewModel.messages.isEmpty)
    }
}
