//
// AppleIntelligenceLLMServiceTests.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

@testable import TENEXCore
import Testing

@Suite("AppleIntelligenceLLMService Tests")
struct AppleIntelligenceLLMServiceTests {
    @Test("AppleIntelligenceError descriptions")
    func errorDescriptions() {
        // Test device not eligible error
        let notEligibleError = AppleIntelligenceError.notAvailable(.deviceNotEligible)
        #expect(notEligibleError.errorDescription?.contains("does not support") == true)

        // Test Apple Intelligence not enabled error
        let notEnabledError = AppleIntelligenceError.notAvailable(.appleIntelligenceNotEnabled)
        #expect(notEnabledError.errorDescription?.contains("not enabled") == true)

        // Test model not ready error
        let notReadyError = AppleIntelligenceError.notAvailable(.modelNotReady)
        #expect(notReadyError.errorDescription?.contains("downloading") == true)

        // Test unsupported OS error
        let unsupportedError = AppleIntelligenceError.notAvailable(.unsupportedOS)
        #expect(unsupportedError.errorDescription?.contains("iOS 26") == true)

        // Test generation failed error
        let genError = AppleIntelligenceError.generationFailed("Test error")
        #expect(genError.errorDescription?.contains("Test error") == true)

        // Test session error
        let sessionError = AppleIntelligenceError.sessionError("Session failed")
        #expect(sessionError.errorDescription?.contains("Session failed") == true)

        // Test unsupported on current OS
        let unsupportedOSError = AppleIntelligenceError.unsupportedOnCurrentOS
        #expect(unsupportedOSError.errorDescription?.contains("iOS 26") == true)
    }

    @Test("AppleIntelligenceGenerationOptions defaults")
    func generationOptionsDefaults() {
        let options = AppleIntelligenceGenerationOptions()
        #expect(options.temperature == 0.7)
        #expect(options.maxTokens == nil)
    }

    @Test("AppleIntelligenceGenerationOptions custom values")
    func generationOptionsCustomValues() {
        let options = AppleIntelligenceGenerationOptions(temperature: 1.5, maxTokens: 500)
        #expect(options.temperature == 1.5)
        #expect(options.maxTokens == 500)
    }

    @Test("AppleIntelligenceGenerationOptions temperature clamping")
    func generationOptionsTemperatureClamping() {
        // Test below minimum
        let lowOptions = AppleIntelligenceGenerationOptions(temperature: -0.5)
        #expect(lowOptions.temperature == 0.0)

        // Test above maximum
        let highOptions = AppleIntelligenceGenerationOptions(temperature: 3.0)
        #expect(highOptions.temperature == 2.0)

        // Test within range
        let normalOptions = AppleIntelligenceGenerationOptions(temperature: 1.0)
        #expect(normalOptions.temperature == 1.0)
    }

    @Test("Fallback service returns unsupported OS")
    func fallbackServiceReturnsUnsupportedOS() {
        let service = AppleIntelligenceLLMServiceFallback()
        let availability = service.checkAvailability()
        #expect(availability == .unavailable(.unsupportedOS))
    }

    @Test("Fallback service generate throws")
    func fallbackServiceGenerateThrows() async throws {
        let service = AppleIntelligenceLLMServiceFallback()
        do {
            _ = try await service.generate(
                prompt: "Hello",
                instructions: nil,
                options: AppleIntelligenceGenerationOptions()
            )
            Issue.record("Expected error to be thrown")
        } catch let error as AppleIntelligenceError {
            if case .unsupportedOnCurrentOS = error {
                // Expected
            } else {
                Issue.record("Expected unsupportedOnCurrentOS error")
            }
        }
    }

    @Test("Fallback service prewarm throws")
    func fallbackServicePrewarmThrows() async throws {
        let service = AppleIntelligenceLLMServiceFallback()
        do {
            try await service.prewarm()
            Issue.record("Expected error to be thrown")
        } catch let error as AppleIntelligenceError {
            if case .unsupportedOnCurrentOS = error {
                // Expected
            } else {
                Issue.record("Expected unsupportedOnCurrentOS error")
            }
        }
    }

    @Test("Factory creates appropriate service")
    func factoryCreatesService() {
        let service = AppleIntelligenceLLMServiceFactory.create()
        // Just verify it doesn't crash and returns a valid service
        _ = service.checkAvailability()
    }
}
