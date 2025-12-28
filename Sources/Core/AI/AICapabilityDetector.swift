//
// AICapabilityDetector.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation
#if canImport(UIKit)
    import UIKit
#endif
#if canImport(FoundationModels)
    import FoundationModels
#endif

// MARK: - AppleIntelligenceUnavailableReason

/// Reasons why Apple Intelligence might be unavailable
public enum AppleIntelligenceUnavailableReason: Sendable, Equatable {
    case deviceNotEligible
    case appleIntelligenceNotEnabled
    case modelNotReady
    case unsupportedOS
    case unknownReason
}

// MARK: - AppleIntelligenceAvailability

/// Availability status for Apple Intelligence
public enum AppleIntelligenceAvailability: Sendable, Equatable {
    case available
    case unavailable(AppleIntelligenceUnavailableReason)
}

// MARK: - AICapabilityDetector

/// Protocol for detecting AI capability availability on the device
public protocol AICapabilityDetector: Sendable {
    /// Check if Apple Intelligence is available
    /// - Returns: True if device supports Apple Intelligence (iOS 26+, compatible device)
    func isAppleIntelligenceAvailable() -> Bool

    /// Get detailed Apple Intelligence availability status
    /// - Returns: Availability status with reason if unavailable
    func getAppleIntelligenceAvailability() -> AppleIntelligenceAvailability

    /// Check if SpeechTranscriber is available
    /// - Returns: True if iOS 18+ (on-device speech recognition via SpeechAnalyzer)
    func isSpeechTranscriberAvailable() -> Bool

    /// Check if WhisperKit is available
    /// - Returns: True if device can run WhisperKit (always true on iOS)
    func isWhisperKitAvailable() -> Bool
}

// MARK: - RuntimeAICapabilityDetector

/// Runtime implementation of AI capability detection
public final class RuntimeAICapabilityDetector: AICapabilityDetector, @unchecked Sendable {
    // MARK: Lifecycle

    public init() {}

    // MARK: Public

    public func isAppleIntelligenceAvailable() -> Bool {
        getAppleIntelligenceAvailability() == .available
    }

    public func getAppleIntelligenceAvailability() -> AppleIntelligenceAvailability {
        #if targetEnvironment(simulator)
            // Apple Intelligence not available in simulator
            return .unavailable(.deviceNotEligible)
        #else
            // iOS 26+ uses Foundation Models framework for Apple Intelligence LLM access
            #if canImport(FoundationModels)
                if #available(iOS 26.0, macOS 26.0, *) {
                    return checkFoundationModelsAvailability()
                }
            #endif

            // Fallback for iOS 18.1-25.x: Use device-based detection
            guard #available(iOS 18.1, *) else {
                return .unavailable(.unsupportedOS)
            }

            // Check device capability (A17+ or M1+ chips)
            if isCompatibleDevice() {
                return .available
            } else {
                return .unavailable(.deviceNotEligible)
            }
        #endif
    }

    public func isSpeechTranscriberAvailable() -> Bool {
        if #available(iOS 18.0, *) {
            return true
        }
        return false
    }

    public func isWhisperKitAvailable() -> Bool {
        // WhisperKit can run on any iOS device
        true
    }

    // MARK: Private

    #if canImport(FoundationModels)
        @available(iOS 26.0, macOS 26.0, *)
        private func checkFoundationModelsAvailability() -> AppleIntelligenceAvailability {
            let model = SystemLanguageModel.default
            switch model.availability {
            case .available:
                return .available
            case .unavailable(let reason):
                switch reason {
                case .deviceNotEligible:
                    return .unavailable(.deviceNotEligible)
                case .appleIntelligenceNotEnabled:
                    return .unavailable(.appleIntelligenceNotEnabled)
                case .modelNotReady:
                    return .unavailable(.modelNotReady)
                @unknown default:
                    return .unavailable(.unknownReason)
                }
            }
        }
    #endif

    #if !targetEnvironment(simulator)
        private func isCompatibleDevice() -> Bool {
            var systemInfo = utsname()
            uname(&systemInfo)

            let machineMirror = Mirror(reflecting: systemInfo.machine)
            let identifier = machineMirror.children.reduce(into: "") { identifier, element in
                guard let value = element.value as? Int8, value != 0 else {
                    return
                }
                identifier += String(UnicodeScalar(UInt8(value)))
            }

            // Apple Intelligence compatible devices (updated for 2025):
            // iPhone 15 Pro series:
            //   - iPhone16,1: iPhone 15 Pro
            //   - iPhone16,2: iPhone 15 Pro Max
            // iPhone 16 series:
            //   - iPhone17,1: iPhone 16 Pro
            //   - iPhone17,2: iPhone 16 Pro Max
            //   - iPhone17,3: iPhone 16
            //   - iPhone17,4: iPhone 16 Plus
            //   - iPhone17,5: iPhone 16e
            // iPhone 17 series:
            //   - iPhone18,1: iPhone 17 Pro
            //   - iPhone18,2: iPhone 17 Pro Max
            //   - iPhone18,3: iPhone 17
            // iPads with M1+ chips:
            //   - iPad13,4-11: iPad Pro 11" (3rd gen) / 12.9" (5th gen) with M1
            //   - iPad14,x: iPad Pro with M2, iPad Air with M2
            //   - iPad16,x: iPad Pro with M4
            let compatibleiPhones = [
                "iPhone16,1", "iPhone16,2",  // iPhone 15 Pro series
                "iPhone17,",                  // iPhone 16 series (all models)
                "iPhone18,",                  // iPhone 17 series (all models)
            ]
            let compatibleiPads = [
                "iPad13,4", "iPad13,5", "iPad13,6", "iPad13,7",  // iPad Pro 11" 3rd gen (M1)
                "iPad13,8", "iPad13,9", "iPad13,10", "iPad13,11", // iPad Pro 12.9" 5th gen (M1)
                "iPad14,",  // iPad Pro/Air M2 series
                "iPad16,",  // iPad Pro M4 series
            ]

            return compatibleiPhones.contains { identifier.hasPrefix($0) } ||
                compatibleiPads.contains { identifier.hasPrefix($0) }
        }
    #endif
}

// MARK: - MockAICapabilityDetector

/// Mock implementation for testing
public final class MockAICapabilityDetector: AICapabilityDetector {
    // MARK: Lifecycle

    public init(
        appleIntelligenceAvailability: AppleIntelligenceAvailability = .unavailable(.deviceNotEligible),
        speechTranscriberAvailable: Bool = false,
        whisperKitAvailable: Bool = true
    ) {
        self.appleIntelligenceAvailabilityValue = appleIntelligenceAvailability
        self.speechTranscriberAvailable = speechTranscriberAvailable
        self.whisperKitAvailable = whisperKitAvailable
    }

    /// Convenience initializer for backward compatibility
    public convenience init(
        appleIntelligenceAvailable: Bool,
        speechTranscriberAvailable: Bool = false,
        whisperKitAvailable: Bool = true
    ) {
        self.init(
            appleIntelligenceAvailability: appleIntelligenceAvailable ? .available : .unavailable(.deviceNotEligible),
            speechTranscriberAvailable: speechTranscriberAvailable,
            whisperKitAvailable: whisperKitAvailable
        )
    }

    // MARK: Public

    public var appleIntelligenceAvailabilityValue: AppleIntelligenceAvailability
    public var speechTranscriberAvailable: Bool
    public var whisperKitAvailable: Bool

    public func isAppleIntelligenceAvailable() -> Bool {
        appleIntelligenceAvailabilityValue == .available
    }

    public func getAppleIntelligenceAvailability() -> AppleIntelligenceAvailability {
        appleIntelligenceAvailabilityValue
    }

    public func isSpeechTranscriberAvailable() -> Bool {
        speechTranscriberAvailable
    }

    public func isWhisperKitAvailable() -> Bool {
        whisperKitAvailable
    }
}
