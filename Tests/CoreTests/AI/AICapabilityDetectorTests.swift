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

    @Test("Mock detector with detailed availability")
    func mockDetectorDetailedAvailability() {
        // Test device not eligible
        let detectorNotEligible = MockAICapabilityDetector(
            appleIntelligenceAvailability: .unavailable(.deviceNotEligible),
            speechTranscriberAvailable: false,
            whisperKitAvailable: true
        )
        #expect(detectorNotEligible.isAppleIntelligenceAvailable() == false)
        #expect(detectorNotEligible.getAppleIntelligenceAvailability() == .unavailable(.deviceNotEligible))

        // Test Apple Intelligence not enabled
        let detectorNotEnabled = MockAICapabilityDetector(
            appleIntelligenceAvailability: .unavailable(.appleIntelligenceNotEnabled),
            speechTranscriberAvailable: true,
            whisperKitAvailable: true
        )
        #expect(detectorNotEnabled.isAppleIntelligenceAvailable() == false)
        #expect(detectorNotEnabled.getAppleIntelligenceAvailability() == .unavailable(.appleIntelligenceNotEnabled))

        // Test model not ready
        let detectorNotReady = MockAICapabilityDetector(
            appleIntelligenceAvailability: .unavailable(.modelNotReady),
            speechTranscriberAvailable: true,
            whisperKitAvailable: true
        )
        #expect(detectorNotReady.isAppleIntelligenceAvailable() == false)
        #expect(detectorNotReady.getAppleIntelligenceAvailability() == .unavailable(.modelNotReady))

        // Test available
        let detectorAvailable = MockAICapabilityDetector(
            appleIntelligenceAvailability: .available,
            speechTranscriberAvailable: true,
            whisperKitAvailable: true
        )
        #expect(detectorAvailable.isAppleIntelligenceAvailable() == true)
        #expect(detectorAvailable.getAppleIntelligenceAvailability() == .available)
    }

    @Test("Runtime detector doesn't crash")
    func runtimeDetectorDoesNotCrash() {
        let detector = RuntimeAICapabilityDetector()

        // These will vary by device/OS, just test they don't crash
        _ = detector.isAppleIntelligenceAvailable()
        _ = detector.getAppleIntelligenceAvailability()
        _ = detector.isSpeechTranscriberAvailable()
        _ = detector.isWhisperKitAvailable()
    }

    @Test("WhisperKit is always available")
    func whisperKitAlwaysAvailable() {
        let detector = RuntimeAICapabilityDetector()
        #expect(detector.isWhisperKitAvailable() == true)
    }

    @Test("AppleIntelligenceUnavailableReason equality")
    func unavailableReasonEquality() {
        #expect(AppleIntelligenceUnavailableReason.deviceNotEligible == .deviceNotEligible)
        #expect(AppleIntelligenceUnavailableReason.appleIntelligenceNotEnabled == .appleIntelligenceNotEnabled)
        #expect(AppleIntelligenceUnavailableReason.modelNotReady == .modelNotReady)
        #expect(AppleIntelligenceUnavailableReason.unsupportedOS == .unsupportedOS)
        #expect(AppleIntelligenceUnavailableReason.deviceNotEligible != .modelNotReady)
    }

    @Test("AppleIntelligenceAvailability equality")
    func availabilityEquality() {
        #expect(AppleIntelligenceAvailability.available == .available)
        #expect(AppleIntelligenceAvailability.unavailable(.deviceNotEligible) == .unavailable(.deviceNotEligible))
        #expect(AppleIntelligenceAvailability.available != .unavailable(.deviceNotEligible))
        #expect(AppleIntelligenceAvailability.unavailable(.modelNotReady) != .unavailable(.deviceNotEligible))
    }
}
