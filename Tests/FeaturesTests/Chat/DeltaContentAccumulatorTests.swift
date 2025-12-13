//
// DeltaContentAccumulatorTests.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation
@testable import TENEXFeatures
import Testing

// MARK: - DeltaContentAccumulatorTests

@Suite("DeltaContentAccumulator Tests")
@MainActor
struct DeltaContentAccumulatorTests {
    // MARK: - In-Order Events

    @Test("Handles in-order events correctly")
    func handlesInOrderEvents() {
        // Given: A new accumulator
        let accumulator = DeltaContentAccumulator()

        // When: Adding events in sequence order
        let content1 = accumulator.addDelta(sequence: 0, content: "Hello")
        let content2 = accumulator.addDelta(sequence: 1, content: " ")
        let content3 = accumulator.addDelta(sequence: 2, content: "world")

        // Then: Content accumulates correctly
        #expect(content1 == "Hello")
        #expect(content2 == "Hello ")
        #expect(content3 == "Hello world")
    }

    @Test("Handles single event")
    func handlesSingleEvent() {
        // Given: A new accumulator
        let accumulator = DeltaContentAccumulator()

        // When: Adding single event
        let content = accumulator.addDelta(sequence: 0, content: "Test")

        // Then: Content is returned
        #expect(content == "Test")
        #expect(accumulator.content == "Test")
    }

    // MARK: - Out-of-Order Events

    @Test("Handles out-of-order events")
    func handlesOutOfOrderEvents() {
        // Given: A new accumulator
        let accumulator = DeltaContentAccumulator()

        // When: Adding events out of order (0, 2, 1)
        let content1 = accumulator.addDelta(sequence: 0, content: "Hello")
        let content2 = accumulator.addDelta(sequence: 2, content: "world")
        let content3 = accumulator.addDelta(sequence: 1, content: " ")

        // Then: Content shows all available deltas in sequence order
        #expect(content1 == "Hello")
        #expect(content2 == "Helloworld") // Shows 0 + 2 (gap at 1)
        #expect(content3 == "Hello world") // Now complete with space
    }

    @Test("Handles reverse order events")
    func handlesReverseOrderEvents() {
        // Given: A new accumulator
        let accumulator = DeltaContentAccumulator()

        // When: Adding events in reverse order
        let content1 = accumulator.addDelta(sequence: 2, content: "C")
        let content2 = accumulator.addDelta(sequence: 1, content: "B")
        let content3 = accumulator.addDelta(sequence: 0, content: "A")

        // Then: Content is reconstructed correctly
        #expect(content1 == "C") // Only has seq 2
        #expect(content2 == "BC") // Has seq 1 and 2
        #expect(content3 == "ABC") // Complete
    }

    @Test("Handles gap in sequence")
    func handlesGapInSequence() {
        // Given: A new accumulator
        let accumulator = DeltaContentAccumulator()

        // When: Adding events with gap (0, 1, 3 - missing 2)
        _ = accumulator.addDelta(sequence: 0, content: "A")
        _ = accumulator.addDelta(sequence: 1, content: "B")
        let content = accumulator.addDelta(sequence: 3, content: "D")

        // Then: Content includes all received deltas in order
        #expect(content == "ABD")

        // When: Gap is filled
        let finalContent = accumulator.addDelta(sequence: 2, content: "C")

        // Then: Content is complete
        #expect(finalContent == "ABCD")
    }

    // MARK: - Edge Cases

    @Test("Ignores empty content")
    func ignoresEmptyContent() {
        // Given: A new accumulator
        let accumulator = DeltaContentAccumulator()

        // When: Adding empty content
        let content1 = accumulator.addDelta(sequence: 0, content: "Hello")
        let content2 = accumulator.addDelta(sequence: 1, content: "")
        let content3 = accumulator.addDelta(sequence: 2, content: "world")

        // Then: Empty content is included (empty string is valid)
        #expect(content1 == "Hello")
        #expect(content2 == "Hello")
        #expect(content3 == "Helloworld")
    }

    @Test("Handles duplicate sequence numbers")
    func handlesDuplicateSequenceNumbers() {
        // Given: A new accumulator
        let accumulator = DeltaContentAccumulator()

        // When: Adding same sequence twice
        _ = accumulator.addDelta(sequence: 0, content: "First")
        let content = accumulator.addDelta(sequence: 0, content: "Second")

        // Then: Later content replaces earlier (last write wins)
        #expect(content == "Second")
    }

    @Test("Clear resets accumulator")
    func clearResetsAccumulator() {
        // Given: An accumulator with content
        let accumulator = DeltaContentAccumulator()
        _ = accumulator.addDelta(sequence: 0, content: "Hello")
        _ = accumulator.addDelta(sequence: 1, content: " world")

        #expect(accumulator.content == "Hello world")

        // When: Clearing the accumulator
        accumulator.clear()

        // Then: Accumulator is reset
        #expect(accumulator.content.isEmpty)

        // And: Can accumulate new content
        let newContent = accumulator.addDelta(sequence: 0, content: "New")
        #expect(newContent == "New")
    }

    // MARK: - Large Sequence Numbers

    @Test("Handles large sequence gaps")
    func handlesLargeSequenceGaps() {
        // Given: A new accumulator
        let accumulator = DeltaContentAccumulator()

        // When: Adding events with large gaps
        _ = accumulator.addDelta(sequence: 0, content: "Start")
        _ = accumulator.addDelta(sequence: 100, content: "End")

        // Then: Content includes both
        #expect(accumulator.content == "StartEnd")
    }

    @Test("Content property reflects current state")
    func contentPropertyReflectsCurrentState() {
        // Given: A new accumulator
        let accumulator = DeltaContentAccumulator()

        // Then: Initially empty
        #expect(accumulator.content.isEmpty)

        // When: Adding content
        _ = accumulator.addDelta(sequence: 0, content: "A")
        #expect(accumulator.content == "A")

        _ = accumulator.addDelta(sequence: 1, content: "B")
        #expect(accumulator.content == "AB")
    }
}
