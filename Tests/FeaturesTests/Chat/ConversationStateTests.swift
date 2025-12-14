//
// ConversationStateTests.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation
import NDKSwiftCore
@testable import TENEXCore
@testable import TENEXFeatures
import Testing

// MARK: - ConversationStateTests

@Suite("ConversationState Tests")
@MainActor
struct ConversationStateTests {
    // MARK: Internal

    // MARK: - Final Messages

    @Test("Processes final message event")
    func processesFinalMessageEvent() {
        // Given: A conversation state
        let state = ConversationState(rootEventID: "test-root")

        // When: Processing a final message event
        let event = createFinalMessageEvent(id: "msg1", content: "Hello world")
        state.processEvent(event)

        // Then: Message is stored
        #expect(state.messages.count == 1)
        #expect(state.messages["msg1"]?.content == "Hello world")
    }

    @Test("Deduplicates final messages by ID")
    func deduplicatesFinalMessages() {
        // Given: A conversation state with a message
        let state = ConversationState(rootEventID: "test-root")
        let event1 = createFinalMessageEvent(id: "msg1", content: "First")
        state.processEvent(event1)

        // When: Processing same message ID again
        let event2 = createFinalMessageEvent(id: "msg1", content: "Second")
        state.processEvent(event2)

        // Then: Only one message exists (last write wins)
        #expect(state.messages.count == 1)
        #expect(state.messages["msg1"]?.content == "Second")
    }

    // MARK: - Streaming Sessions

    @Test("Creates streaming session on first chunk")
    func createsStreamingSessionOnFirstChunk() {
        // Given: A conversation state
        let state = ConversationState(rootEventID: "test-root")

        // When: Processing a streaming delta
        let event = createStreamingEvent(pubkey: "agent1", sequence: 0, content: "Hello")
        state.processEvent(event)

        // Then: Streaming session is created
        #expect(state.streamingSessions.count == 1)
        #expect(state.streamingSessions["agent1"]?.reconstructedContent == "Hello")
    }

    @Test("Accumulates streaming deltas")
    func accumulatesStreamingDeltas() {
        // Given: A conversation state with a streaming session
        let state = ConversationState(rootEventID: "test-root")
        state.processEvent(createStreamingEvent(pubkey: "agent1", sequence: 0, content: "Hello"))

        // When: Processing more deltas
        state.processEvent(createStreamingEvent(pubkey: "agent1", sequence: 1, content: " "))
        state.processEvent(createStreamingEvent(pubkey: "agent1", sequence: 2, content: "world"))

        // Then: Content is accumulated
        #expect(state.streamingSessions["agent1"]?.reconstructedContent == "Hello world")
    }

    @Test("Multiple agents can stream simultaneously")
    func multipleAgentsCanStreamSimultaneously() {
        // Given: A conversation state
        let state = ConversationState(rootEventID: "test-root")

        // When: Two agents stream simultaneously
        state.processEvent(createStreamingEvent(pubkey: "agent1", sequence: 0, content: "From agent 1"))
        state.processEvent(createStreamingEvent(pubkey: "agent2", sequence: 0, content: "From agent 2"))

        // Then: Both sessions exist
        #expect(state.streamingSessions.count == 2)
        #expect(state.streamingSessions["agent1"]?.reconstructedContent == "From agent 1")
        #expect(state.streamingSessions["agent2"]?.reconstructedContent == "From agent 2")
    }

    // MARK: - Final Message Clears Streaming

    @Test("Final message clears streaming session immediately")
    func finalMessageClearsStreamingSession() {
        // Given: A conversation state with an active streaming session
        let state = ConversationState(rootEventID: "test-root")
        state.processEvent(createStreamingEvent(pubkey: "agent1", sequence: 0, content: "Streaming..."))

        #expect(state.streamingSessions.count == 1)

        // When: Final message arrives from same pubkey
        let finalEvent = createFinalMessageEvent(id: "final1", content: "Final message", pubkey: "agent1")
        state.processEvent(finalEvent)

        // Then: Message is stored and streaming session is cleared immediately
        #expect(state.messages.count == 1)
        #expect(state.streamingSessions.isEmpty)
    }

    // MARK: - Typing Indicators

    @Test("Typing start adds indicator")
    func typingStartAddsIndicator() {
        // Given: A conversation state
        let state = ConversationState(rootEventID: "test-root")

        // When: Typing start event arrives
        let event = createTypingEvent(pubkey: "agent1", isStart: true)
        state.processEvent(event)

        // Then: Typing indicator is stored
        #expect(state.typingIndicators.count == 1)
        #expect(state.typingIndicators["agent1"] != nil)
    }

    @Test("Typing stop removes indicator")
    func typingStopRemovesIndicator() {
        // Given: A conversation state with typing indicator
        let state = ConversationState(rootEventID: "test-root")
        state.processEvent(createTypingEvent(pubkey: "agent1", isStart: true))

        // When: Typing stop event arrives
        state.processEvent(createTypingEvent(pubkey: "agent1", isStart: false))

        // Then: Typing indicator is removed
        #expect(state.typingIndicators.isEmpty)
    }

    @Test("Final message clears typing indicator")
    func finalMessageClearsTypingIndicator() {
        // Given: A conversation state with typing indicator
        let state = ConversationState(rootEventID: "test-root")
        state.processEvent(createTypingEvent(pubkey: "agent1", isStart: true))

        // When: Final message arrives from same pubkey
        let finalEvent = createFinalMessageEvent(id: "msg1", content: "Done", pubkey: "agent1")
        state.processEvent(finalEvent)

        // Then: Typing indicator is removed
        #expect(state.typingIndicators.isEmpty)
    }

    // MARK: - Display Messages

    @Test("Display messages includes final messages")
    func displayMessagesIncludesFinalMessages() {
        // Given: A conversation state with messages
        let state = ConversationState(rootEventID: "test-root")
        state.processEvent(createFinalMessageEvent(id: "msg1", content: "First"))
        state.processEvent(createFinalMessageEvent(id: "msg2", content: "Second"))

        // Then: Display messages includes both
        #expect(state.displayMessages.count == 2)
    }

    @Test("Display messages includes streaming as synthetic messages")
    func displayMessagesIncludesStreamingAsSynthetic() {
        // Given: A conversation state with streaming session
        let state = ConversationState(rootEventID: "test-root")
        state.processEvent(createStreamingEvent(pubkey: "agent1", sequence: 0, content: "Streaming"))

        // Then: Display messages includes synthetic message
        #expect(state.displayMessages.count == 1)
        #expect(state.displayMessages.first?.isStreaming == true)
    }

    @Test("Display messages sorted by creation time")
    func displayMessagesSortedByTime() {
        // Given: A conversation state with messages at different times
        let state = ConversationState(rootEventID: "test-root")
        state.processEvent(createFinalMessageEvent(id: "msg2", content: "Second", createdAt: 2000))
        state.processEvent(createFinalMessageEvent(id: "msg1", content: "First", createdAt: 1000))
        state.processEvent(createFinalMessageEvent(id: "msg3", content: "Third", createdAt: 3000))

        // Then: Display messages are sorted oldest first
        let messages = state.displayMessages
        #expect(messages.count == 3)
        #expect(messages[0].content == "First")
        #expect(messages[1].content == "Second")
        #expect(messages[2].content == "Third")
    }

    // MARK: - Reply Metadata

    @Test("Direct reply to root with no nested replies has zero reply count")
    func directReplyWithNoNestedRepliesHasZeroCount() {
        // Given: A conversation state with root and a direct reply
        let state = ConversationState(rootEventID: "root")
        state.addOptimisticMessage(createMessage(id: "root", content: "Root message"))
        state.addOptimisticMessage(createMessage(id: "msg1", content: "Direct reply", replyTo: "root"))

        // Then: Direct reply has zero nested reply count
        let message = state.displayMessages.first { $0.id == "msg1" }
        #expect(message?.replyCount == 0)
        #expect(message?.replyAuthorPubkeys.isEmpty == true)
    }

    @Test("Direct reply with nested replies has correct reply count")
    func directReplyWithNestedRepliesHasCorrectCount() {
        // Given: A conversation state with root, a direct reply, and nested replies
        let state = ConversationState(rootEventID: "root")
        state.addOptimisticMessage(createMessage(id: "root", content: "Root message"))
        state.addOptimisticMessage(createMessage(id: "parent", content: "Direct reply", replyTo: "root"))

        // When: Nested replies are added (replies to the direct reply)
        state.addOptimisticMessage(createMessage(id: "reply1", content: "Reply 1", replyTo: "parent", pubkey: "user1"))
        state.addOptimisticMessage(createMessage(id: "reply2", content: "Reply 2", replyTo: "parent", pubkey: "user2"))
        state.addOptimisticMessage(createMessage(id: "reply3", content: "Reply 3", replyTo: "parent", pubkey: "user3"))

        // Then: Direct reply has correct nested reply count
        // Note: nested replies are NOT in displayMessages (they're hidden behind reply indicator)
        let parentMessage = state.displayMessages.first { $0.id == "parent" }
        #expect(parentMessage?.replyCount == 3)
        #expect(parentMessage?.replyAuthorPubkeys.count == 3)

        // Verify nested replies are not shown in displayMessages
        #expect(state.displayMessages.count == 2) // root + parent only
    }

    @Test("Reply author pubkeys are unique and capped at 3")
    func replyAuthorPubkeysAreCappedAtThree() {
        // Given: A direct reply with many nested replies from same and different users
        let state = ConversationState(rootEventID: "root")
        state.addOptimisticMessage(createMessage(id: "root", content: "Root message"))
        state.addOptimisticMessage(createMessage(id: "parent", content: "Direct reply", replyTo: "root"))

        // When: Adding 5 nested replies from 4 unique users (user1 replies twice)
        state.addOptimisticMessage(createMessage(id: "r1", content: "R1", replyTo: "parent", pubkey: "user1"))
        state.addOptimisticMessage(createMessage(id: "r2", content: "R2", replyTo: "parent", pubkey: "user2"))
        state.addOptimisticMessage(createMessage(id: "r3", content: "R3", replyTo: "parent", pubkey: "user1"))
        state.addOptimisticMessage(createMessage(id: "r4", content: "R4", replyTo: "parent", pubkey: "user3"))
        state.addOptimisticMessage(createMessage(id: "r5", content: "R5", replyTo: "parent", pubkey: "user4"))

        // Then: Reply count is 5, but unique pubkeys capped at 3
        let parentMessage = state.displayMessages.first { $0.id == "parent" }
        #expect(parentMessage?.replyCount == 5)
        #expect(parentMessage?.replyAuthorPubkeys.count == 3)
    }

    @Test("Root message does not show reply count for direct replies")
    func rootMessageDoesNotShowReplyCount() {
        // Given: A root message with direct replies
        let state = ConversationState(rootEventID: "root")
        state.addOptimisticMessage(createMessage(id: "root", content: "Root message"))
        state.addOptimisticMessage(createMessage(id: "reply1", content: "Reply 1", replyTo: "root", pubkey: "user1"))
        state.addOptimisticMessage(createMessage(id: "reply2", content: "Reply 2", replyTo: "root", pubkey: "user2"))

        // Then: Root message has zero reply count (direct replies are shown inline)
        let rootMessage = state.displayMessages.first { $0.id == "root" }
        #expect(rootMessage?.replyCount == 0)

        // And direct replies are shown in displayMessages
        #expect(state.displayMessages.count == 3)
    }

    @Test("Only root and direct replies are shown in displayMessages")
    func onlyRootAndDirectRepliesAreShown() {
        // Given: A thread with root, direct replies, and nested replies
        let state = ConversationState(rootEventID: "root")
        state.addOptimisticMessage(createMessage(id: "root", content: "Root"))
        state.addOptimisticMessage(createMessage(id: "direct1", content: "Direct 1", replyTo: "root"))
        state.addOptimisticMessage(createMessage(id: "direct2", content: "Direct 2", replyTo: "root"))
        state.addOptimisticMessage(createMessage(id: "nested1", content: "Nested 1", replyTo: "direct1"))
        state.addOptimisticMessage(createMessage(id: "nested2", content: "Nested 2", replyTo: "direct1"))

        // Then: Only root and direct replies are in displayMessages
        let displayedIDs = Set(state.displayMessages.map(\.id))
        #expect(displayedIDs == ["root", "direct1", "direct2"])

        // And direct1 has reply count for its nested replies
        let direct1 = state.displayMessages.first { $0.id == "direct1" }
        #expect(direct1?.replyCount == 2)
    }

    // MARK: Private

    // MARK: - Helpers

    private func createFinalMessageEvent(
        id: String,
        content: String,
        pubkey: String = "user1",
        createdAt: Int64 = Int64(Date().timeIntervalSince1970)
    ) -> NDKEvent {
        NDKEvent(
            id: id,
            pubkey: pubkey,
            createdAt: createdAt,
            kind: 1111,
            tags: [],
            content: content,
            sig: "test-sig"
        )
    }

    private func createStreamingEvent(
        pubkey: String,
        sequence: Int,
        content: String
    ) -> NDKEvent {
        NDKEvent(
            id: UUID().uuidString,
            pubkey: pubkey,
            createdAt: Int64(Date().timeIntervalSince1970),
            kind: 21_111,
            tags: [["sequence", "\(sequence)"]],
            content: content,
            sig: "test-sig"
        )
    }

    private func createTypingEvent(pubkey: String, isStart: Bool) -> NDKEvent {
        NDKEvent(
            id: UUID().uuidString,
            pubkey: pubkey,
            createdAt: Int64(Date().timeIntervalSince1970),
            kind: isStart ? 24_111 : 24_112,
            tags: [],
            content: "",
            sig: "test-sig"
        )
    }

    private func createMessage(
        id: String,
        content: String,
        replyTo: String? = nil,
        pubkey: String = "default-user"
    ) -> Message {
        Message(
            id: id,
            pubkey: pubkey,
            threadID: "test-thread",
            content: content,
            createdAt: Date(),
            replyTo: replyTo
        )
    }
}
