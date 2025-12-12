//
//  TENEXSharedTests.swift
//  TENEX
//

import SwiftUI
@testable import TENEXShared
import Testing

@Suite("TENEXShared Module Tests")
struct TENEXSharedTests {
    @Test("Module version is defined")
    func moduleVersionIsDefined() {
        #expect(TENEXShared.version == "0.1.0")
    }

    @Test("Deterministic color generates consistent hue for same string")
    func deterministicColorIsConsistent() {
        let color1 = Color.deterministicColor(for: "TENEX iOS")
        let color2 = Color.deterministicColor(for: "TENEX iOS")

        // Colors should be identical for the same input
        #expect(color1 == color2)
    }

    @Test("Deterministic color generates different hues for different strings")
    func deterministicColorVariesByInput() {
        let color1 = Color.deterministicColor(for: "Project A")
        let color2 = Color.deterministicColor(for: "Project B")

        // Colors should differ for different inputs
        // Note: There's a small chance of collision, but extremely unlikely
        #expect(color1 != color2)
    }

    @Test("Conversation phases have distinct colors")
    func conversationPhasesHaveDistinctColors() {
        let phases = ConversationPhase.allCases
        let colors = phases.map(\.color)

        // At least some colors should be different
        let uniqueColors = Set(colors.map(\.description))
        #expect(uniqueColors.count > 1)
    }

    @Test("All conversation phases have a color")
    func allPhasesHaveColors() {
        for phase in ConversationPhase.allCases {
            // This will fail if any phase throws when accessing color
            _ = phase.color
        }
    }
}
