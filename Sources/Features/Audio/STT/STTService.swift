//
// STTService.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation

// MARK: - STTService

/// Protocol defining speech-to-text transcription capabilities
protocol STTService: Sendable {
    /// Transcribe audio data to text
    /// - Parameter audioData: Audio data to transcribe (format varies by provider)
    /// - Returns: Transcribed text
    func transcribe(audioData: Data) async throws -> String

    /// Transcribe audio file to text
    /// - Parameter audioURL: URL to audio file
    /// - Returns: Transcribed text
    func transcribe(audioURL: URL) async throws -> String

    /// Whether this service is currently available
    var isAvailable: Bool { get async }

    /// Whether this service requires network connectivity
    var requiresNetwork: Bool { get }
}

/// Default implementation for transcribing from Data
extension STTService {
    func transcribe(audioData: Data) async throws -> String {
        // Write data to temporary file
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent("stt_\(UUID().uuidString).wav")

        try audioData.write(to: tempFile)

        defer {
            try? FileManager.default.removeItem(at: tempFile)
        }

        return try await transcribe(audioURL: tempFile)
    }
}
