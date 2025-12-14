//
// ElevenLabsTTSService.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import ElevenlabsSwift
import Foundation

/// Primary TTS service using ElevenLabs API
final class ElevenLabsTTSService: TTSService {
    // MARK: Lifecycle

    init(apiKey: String) {
        self.apiKey = apiKey
        client = ElevenlabsSwift(elevenLabsAPI: apiKey)
    }

    // MARK: Internal

    var supportedVoices: [VoiceConfig] {
        [
            VoiceConfig(
                name: "Rachel",
                provider: .elevenlabs,
                voiceID: "21m00Tcm4TlvDq8ikWAM",
                metadata: VoiceMetadata(gender: "Female", accent: "American", ageRange: "Adult")
            ),
            VoiceConfig(
                name: "Domi",
                provider: .elevenlabs,
                voiceID: "AZnzlk1XvdvUeBnXmlld",
                metadata: VoiceMetadata(gender: "Female", accent: "American", ageRange: "Adult")
            ),
            VoiceConfig(
                name: "Adam",
                provider: .elevenlabs,
                voiceID: "pNInz6obpgDQGcFmaJgB",
                metadata: VoiceMetadata(gender: "Male", accent: "American", ageRange: "Adult")
            ),
            VoiceConfig(
                name: "Antoni",
                provider: .elevenlabs,
                voiceID: "ErXwobaYiN019PkySvjV",
                metadata: VoiceMetadata(gender: "Male", accent: "American", ageRange: "Adult")
            ),
        ]
    }

    var isAvailable: Bool {
        get async {
            !apiKey.isEmpty
        }
    }

    func synthesize(text: String, voiceID: String?) async throws -> Data {
        guard !apiKey.isEmpty else {
            throw AudioError.noAPIKey(provider: "ElevenLabs")
        }

        let voice = voiceID ?? Self.defaultVoiceID

        do {
            // Use ElevenLabs SDK to synthesize speech - returns URL to audio file
            let audioURL = try await client.textToSpeech(voice_id: voice, text: text)

            // Read the audio file data
            let audioData = try Data(contentsOf: audioURL)

            // Clean up the temporary file
            try? FileManager.default.removeItem(at: audioURL)

            return audioData
        } catch {
            throw AudioError.synthesisFailed(error)
        }
    }

    func synthesizeStream(text _: String, voiceID _: String?) async throws -> AsyncThrowingStream<Data, Error> {
        // ElevenlabsSwift doesn't support streaming, return single chunk
        throw AudioError.synthesisFailed(NSError(
            domain: "ElevenLabsTTS",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: "Streaming not supported by this provider"]
        ))
    }

    // MARK: Private

    /// Default voice ID (Rachel)
    private static let defaultVoiceID = "21m00Tcm4TlvDq8ikWAM"

    private let apiKey: String
    private let client: ElevenlabsSwift
}
