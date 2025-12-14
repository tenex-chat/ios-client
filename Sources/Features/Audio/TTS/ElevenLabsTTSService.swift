//
// ElevenLabsTTSService.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import ElevenLabsSwift
import Foundation

/// Primary TTS service using ElevenLabs API
final class ElevenLabsTTSService: TTSService {
    // MARK: Lifecycle

    init(apiKey: String) {
        self.apiKey = apiKey
        client = ElevenLabs(apiKey: apiKey)
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
            // Use ElevenLabs SDK to synthesize speech
            let audio = try await client.textToSpeech.convert(
                text: text,
                voiceID: voice
            )

            return audio
        } catch {
            throw AudioError.synthesisFailed(error)
        }
    }

    func synthesizeStream(text: String, voiceID: String?) async throws -> AsyncThrowingStream<Data, Error> {
        guard !apiKey.isEmpty else {
            throw AudioError.noAPIKey(provider: "ElevenLabs")
        }

        let voice = voiceID ?? Self.defaultVoiceID

        return AsyncThrowingStream { continuation in
            Task {
                do {
                    // Use streaming endpoint for lower latency
                    let stream = try await client.textToSpeech.convertStream(
                        text: text,
                        voiceID: voice
                    )

                    for try await chunk in stream {
                        continuation.yield(chunk)
                    }

                    continuation.finish()
                } catch {
                    continuation.finish(throwing: AudioError.synthesisFailed(error))
                }
            }
        }
    }

    // MARK: Private

    /// Default voice ID (Rachel)
    private static let defaultVoiceID = "21m00Tcm4TlvDq8ikWAM"

    private let apiKey: String
    private let client: ElevenLabs
}
