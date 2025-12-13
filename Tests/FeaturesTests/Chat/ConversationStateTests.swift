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
        let state = ConversationState()

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
        let state = ConversationState()
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
        let state = ConversationState()

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
        let state = ConversationState()
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
        let state = ConversationState()

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
        let state = ConversationState()
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
        let state = ConversationState()

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
        let state = ConversationState()
        state.processEvent(createTypingEvent(pubkey: "agent1", isStart: true))

        // When: Typing stop event arrives
        state.processEvent(createTypingEvent(pubkey: "agent1", isStart: false))

        // Then: Typing indicator is removed
        #expect(state.typingIndicators.isEmpty)
    }

    @Test("Final message clears typing indicator")
    func finalMessageClearsTypingIndicator() {
        // Given: A conversation state with typing indicator
        let state = ConversationState()
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
        let state = ConversationState()
        state.processEvent(createFinalMessageEvent(id: "msg1", content: "First"))
        state.processEvent(createFinalMessageEvent(id: "msg2", content: "Second"))

        // Then: Display messages includes both
        #expect(state.displayMessages.count == 2)
    }

    @Test("Display messages includes streaming as synthetic messages")
    func displayMessagesIncludesStreamingAsSynthetic() {
        // Given: A conversation state with streaming session
        let state = ConversationState()
        state.processEvent(createStreamingEvent(pubkey: "agent1", sequence: 0, content: "Streaming"))

        // Then: Display messages includes synthetic message
        #expect(state.displayMessages.count == 1)
        #expect(state.displayMessages.first?.isStreaming == true)
    }

    @Test("Display messages sorted by creation time")
    func displayMessagesSortedByTime() {
        // Given: A conversation state with messages at different times
        let state = ConversationState()
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
}
