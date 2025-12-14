//
// TTSService.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation

// MARK: - TTSService

/// Protocol defining text-to-speech synthesis capabilities
protocol TTSService: Sendable {
    /// Synthesize text to audio data (full synthesis)
    /// - Parameters:
    ///   - text: The text to synthesize
    ///   - voiceID: Optional voice identifier (provider-specific)
    /// - Returns: Audio data (format varies by provider)
    func synthesize(text: String, voiceID: String?) async throws -> Data

    /// Synthesize text to audio stream (streaming synthesis)
    /// - Parameters:
    ///   - text: The text to synthesize
    ///   - voiceID: Optional voice identifier (provider-specific)
    /// - Returns: Async stream of audio data chunks
    func synthesizeStream(text: String, voiceID: String?) async throws -> AsyncThrowingStream<Data, Error>

    /// List of supported voices for this provider
    var supportedVoices: [VoiceConfig] { get }

    /// Whether this service is currently available
    var isAvailable: Bool { get async }
}

/// Default implementation for streaming (returns full synthesis as single chunk)
extension TTSService {
    func synthesizeStream(text: String, voiceID: String?) async throws -> AsyncThrowingStream<Data, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let data = try await synthesize(text: text, voiceID: voiceID)
                    continuation.yield(data)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}
