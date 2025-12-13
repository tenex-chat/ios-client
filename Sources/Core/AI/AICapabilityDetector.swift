//
// AICapabilityDetector.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation
#if canImport(UIKit)
    import UIKit
#endif

// MARK: - AICapabilityDetector

/// Protocol for detecting AI capability availability on the device
public protocol AICapabilityDetector: Sendable {
    /// Check if Apple Intelligence is available
    /// - Returns: True if device supports Apple Intelligence (iOS 18.1+, A17+/M1+ chips)
    func isAppleIntelligenceAvailable() -> Bool

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
        #if targetEnvironment(simulator)
            // Apple Intelligence not available in simulator
            return false
        #else
            // Require iOS 18.1+
            guard #available(iOS 18.1, *) else {
                return false
            }

            // Check device capability (A17+ or M1+ chips)
            return isCompatibleDevice()
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

            // Apple Intelligence compatible devices:
            // - iPhone 15 Pro: iPhone16,1
            // - iPhone 15 Pro Max: iPhone16,2
            // - iPhone 16 series: iPhone17,x
            // - iPad with M1+: iPad14,x and newer
            let compatibleiPhones = ["iPhone16,1", "iPhone16,2", "iPhone17,"]
            let compatibleiPads = ["iPad14,", "iPad16,"]

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
        appleIntelligenceAvailable: Bool = false,
        speechTranscriberAvailable: Bool = false,
        whisperKitAvailable: Bool = true
    ) {
        self.appleIntelligenceAvailable = appleIntelligenceAvailable
        self.speechTranscriberAvailable = speechTranscriberAvailable
        self.whisperKitAvailable = whisperKitAvailable
    }

    // MARK: Public

    public var appleIntelligenceAvailable: Bool
    public var speechTranscriberAvailable: Bool
    public var whisperKitAvailable: Bool

    public func isAppleIntelligenceAvailable() -> Bool {
        appleIntelligenceAvailable
    }

    public func isSpeechTranscriberAvailable() -> Bool {
        speechTranscriberAvailable
    }

    public func isWhisperKitAvailable() -> Bool {
        whisperKitAvailable
    }
}
