//
// WhisperKitSTT.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation
import WhisperKit

/// Fallback STT service using on-device Whisper model
final class WhisperKitSTT: STTService {
    // MARK: Lifecycle

    init(modelSize: String = "tiny") {
        self.modelSize = modelSize
    }

    // MARK: Internal

    var isAvailable: Bool {
        get async {
            true // WhisperKit is always available (downloads model on demand)
        }
    }

    var requiresNetwork: Bool {
        false // On-device transcription (requires network for initial model download only)
    }

    func transcribe(audioURL: URL) async throws -> String {
        // Initialize WhisperKit if needed (downloads model on first use)
        if whisperKit == nil {
            do {
                whisperKit = try await WhisperKit(model: modelSize)
            } catch {
                throw AudioError.transcriptionFailed(error)
            }
        }

        guard let whisperKit else {
            throw AudioError.serviceUnavailable("WhisperKit")
        }

        do {
            // Transcribe audio file
            let results = try await whisperKit.transcribe(audioPath: audioURL.path)
            // Combine all transcription segments
            return results.map(\.text).joined(separator: " ")
        } catch {
            throw AudioError.transcriptionFailed(error)
        }
    }

    // MARK: Private

    private var whisperKit: WhisperKit?
    private let modelSize: String
}
