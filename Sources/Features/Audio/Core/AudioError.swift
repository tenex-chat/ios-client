//
// AudioError.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation

/// Errors that can occur during audio operations
enum AudioError: LocalizedError {
    case permissionDenied
    case recordingFailed(Error)
    case transcriptionFailed(Error)
    case synthesisFailed(Error)
    case playbackFailed(Error)
    case noAPIKey(provider: String)
    case networkError(Error)
    case unsupportedFormat
    case interrupted
    case serviceUnavailable(String)

    // MARK: Internal

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            "Microphone or speech recognition access required"
        case let .recordingFailed(error):
            "Recording failed: \(error.localizedDescription)"
        case let .transcriptionFailed(error):
            "Transcription failed: \(error.localizedDescription)"
        case let .synthesisFailed(error):
            "Speech synthesis failed: \(error.localizedDescription)"
        case let .playbackFailed(error):
            "Playback failed: \(error.localizedDescription)"
        case let .noAPIKey(provider):
            "API key required for \(provider)"
        case let .networkError(error):
            "Network error: \(error.localizedDescription)"
        case .unsupportedFormat:
            "Unsupported audio format"
        case .interrupted:
            "Audio session interrupted"
        case let .serviceUnavailable(service):
            "\(service) service is not available"
        }
    }
}
