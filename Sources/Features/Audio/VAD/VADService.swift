//
// VADService.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import AVFoundation
import Foundation

// MARK: - VADService

/// Protocol defining Voice Activity Detection interface
@MainActor
protocol VADService: Sendable {
    /// Start VAD with audio engine
    /// - Parameter audioEngine: AVAudioEngine to monitor
    func start(audioEngine: AVAudioEngine) async throws

    /// Stop VAD and cleanup resources
    func stop() async

    /// Update sensitivity threshold
    /// - Parameter sensitivity: Sensitivity value (0.0-1.0)
    func updateSensitivity(_ sensitivity: Double)

    /// Callback when speech starts
    var onSpeechStart: (@Sendable () -> Void)? { get set }

    /// Callback when speech ends
    var onSpeechEnd: (@Sendable () -> Void)? { get set }

    /// Callback when error occurs
    var onError: (@Sendable (Error) -> Void)? { get set }
}

// MARK: - VADError

/// Errors that can occur during VAD operations
enum VADError: LocalizedError {
    case permissionDenied
    case audioEngineNotRunning
    case serviceUnavailable
    case initializationFailed(Error)
    case processingFailed(Error)

    // MARK: Internal

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            "Microphone access required for voice detection"
        case .audioEngineNotRunning:
            "Audio engine must be running to start VAD"
        case .serviceUnavailable:
            "Voice detection service is not available"
        case let .initializationFailed(error):
            "Failed to initialize VAD: \(error.localizedDescription)"
        case let .processingFailed(error):
            "VAD processing failed: \(error.localizedDescription)"
        }
    }
}
