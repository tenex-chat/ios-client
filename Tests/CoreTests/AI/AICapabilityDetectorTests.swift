//
// AICapabilityDetectorTests.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

@testable import TENEXCore
import Testing

@Suite("AICapabilityDetector Tests")
struct AICapabilityDetectorTests {
    @Test("Mock detector with all capabilities available")
    func mockDetectorAllAvailable() {
        let detector = MockAICapabilityDetector(
            appleIntelligenceAvailable: true,
            speechTranscriberAvailable: true,
            whisperKitAvailable: true
        )

        #expect(detector.isAppleIntelligenceAvailable() == true)
        #expect(detector.isSpeechTranscriberAvailable() == true)
        #expect(detector.isWhisperKitAvailable() == true)
    }

    @Test("Mock detector with no capabilities")
    func mockDetectorNoneAvailable() {
        let detector = MockAICapabilityDetector(
            appleIntelligenceAvailable: false,
            speechTranscriberAvailable: false,
            whisperKitAvailable: false
        )

        #expect(detector.isAppleIntelligenceAvailable() == false)
        #expect(detector.isSpeechTranscriberAvailable() == false)
        #expect(detector.isWhisperKitAvailable() == false)
    }

    @Test("Runtime detector doesn't crash")
    func runtimeDetectorDoesNotCrash() {
        let detector = RuntimeAICapabilityDetector()

        // These will vary by device/OS, just test they don't crash
        _ = detector.isAppleIntelligenceAvailable()
        _ = detector.isSpeechTranscriberAvailable()
        _ = detector.isWhisperKitAvailable()
    }

    @Test("WhisperKit is always available")
    func whisperKitAlwaysAvailable() {
        let detector = RuntimeAICapabilityDetector()
        #expect(detector.isWhisperKitAvailable() == true)
    }
}
