//
// StreamingSessionTests.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation
import NDKSwiftCore
@testable import TENEXFeatures
import Testing

// MARK: - StreamingSessionTests

@Suite("StreamingSession Tests")
@MainActor
struct StreamingSessionTests {
    // MARK: Internal

    // MARK: - Initialization

    @Test("Creates session with synthetic ID and accumulator")
    func createsSessionWithSyntheticIDAndAccumulator() {
        // Given: An event
        let event = createStreamingEvent(sequence: 0, content: "Hello")

        // When: Creating a session
        let session = StreamingSession(event: event)

        // Then: Session has a synthetic ID and accumulator
        #expect(!session.syntheticID.isEmpty)
        #expect(session.latestEvent.id == event.id)
    }

    @Test("First event initializes accumulator with content")
    func firstEventInitializesAccumulator() {
        // Given: An event with content
        let event = createStreamingEvent(sequence: 0, content: "Hello")

        // When: Creating a session
        let session = StreamingSession(event: event)

        // Then: Accumulator has the content
        #expect(session.reconstructedContent == "Hello")
    }

    // MARK: - Adding Deltas

    @Test("Adding delta updates reconstructed content")
    func addingDeltaUpdatesContent() {
        // Given: A session with initial content
        let event = createStreamingEvent(sequence: 0, content: "Hello")
        var session = StreamingSession(event: event)

        // When: Adding another delta
        let event2 = createStreamingEvent(sequence: 1, content: " world")
        session.addDelta(from: event2)

        // Then: Content is accumulated
        #expect(session.reconstructedContent == "Hello world")
    }

    @Test("Adding out-of-order delta reconstructs correctly")
    func addingOutOfOrderDelta() {
        // Given: A session
        let event = createStreamingEvent(sequence: 0, content: "A")
        var session = StreamingSession(event: event)

        // When: Adding out of order deltas
        let event2 = createStreamingEvent(sequence: 2, content: "C")
        session.addDelta(from: event2)
        let event3 = createStreamingEvent(sequence: 1, content: "B")
        session.addDelta(from: event3)

        // Then: Content is correctly ordered
        #expect(session.reconstructedContent == "ABC")
    }

    @Test("Latest event is updated on each delta")
    func latestEventIsUpdated() {
        // Given: A session
        let event1 = createStreamingEvent(sequence: 0, content: "A")
        var session = StreamingSession(event: event1)

        // When: Adding another delta
        let event2 = createStreamingEvent(sequence: 1, content: "B")
        session.addDelta(from: event2)

        // Then: Latest event is the most recent
        #expect(session.latestEvent.id == event2.id)
    }

    // MARK: Private

    // MARK: - Helpers

    private func createStreamingEvent(sequence: Int, content: String) -> NDKEvent {
        NDKEvent(
            id: UUID().uuidString,
            pubkey: "test-pubkey",
            createdAt: Int64(Date().timeIntervalSince1970),
            kind: 21_111,
            tags: [["sequence", "\(sequence)"]],
            content: content,
            sig: "test-sig"
        )
    }
}
