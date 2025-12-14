//
// AudioService.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation
import Observation
import TENEXCore

/// Main audio service coordinator
/// Orchestrates TTS, STT, recording, and playback with automatic fallbacks
@MainActor
@Observable
public final class AudioService {
    // MARK: Lifecycle

    /// Initialize the audio service with storage and capability detector
    /// - Parameters:
    ///   - storage: AI configuration storage for API keys
    ///   - capabilityDetector: Detector for runtime AI capabilities
    public init(storage: AIConfigStorage, capabilityDetector: AICapabilityDetector) {
        self.storage = storage
        recorder = AudioRecorder()
        player = AudioPlayer()

        // Initialize TTS services
        // Primary: ElevenLabs (if API key available)
        // Fallback: System
        if let apiKey = try? storage.loadAPIKey(for: "elevenlabs"), !apiKey.isEmpty {
            ttsService = ElevenLabsTTSService(apiKey: apiKey)
        } else {
            ttsService = SystemTTSService()
        }
        ttsFallback = SystemTTSService()

        // Initialize STT services
        // Primary: SpeechTranscriber (iOS 18+) or WhisperKit (fallback)
        // Fallback: WhisperKit
        if #available(iOS 18.0, macOS 15.0, *),
           capabilityDetector.isSpeechTranscriberAvailable(),
           let speechTranscriber = SpeechTranscriberSTT() {
            sttService = speechTranscriber
        } else {
            sttService = WhisperKitSTT()
        }
        sttFallback = WhisperKitSTT()
    }

    // MARK: Internal

    // Audio components
    let recorder: AudioRecorder
    let player: AudioPlayer

    /// State
    private(set) var error: AudioError?

    // MARK: - Service Information

    /// Get current TTS provider name
    var currentTTSProvider: String {
        if ttsService is ElevenLabsTTSService {
            "ElevenLabs"
        } else {
            "System"
        }
    }

    /// Get current STT provider name
    var currentSTTProvider: String {
        if #available(iOS 18.0, macOS 15.0, *), sttService is SpeechTranscriberSTT {
            "SpeechTranscriber"
        } else {
            "WhisperKit"
        }
    }

    /// Check if TTS is available
    var isTTSAvailable: Bool {
        get async {
            await ttsService.isAvailable
        }
    }

    /// Check if STT is available
    var isSTTAvailable: Bool {
        get async {
            await sttService.isAvailable
        }
    }

    // MARK: - Recording & Transcription

    /// Start recording audio
    func startRecording() async throws {
        error = nil
        try await recorder.startRecording()
    }

    /// Stop recording and transcribe the audio
    /// - Returns: Transcribed text
    func stopRecording() async throws -> String {
        error = nil

        // Stop recording and get audio file
        let audioURL = try await recorder.stopRecording()

        // Transcribe with primary service
        do {
            return try await sttService.transcribe(audioURL: audioURL)
        } catch {
            // Try fallback service
            // swiftlint:disable:next no_print_statements
            print("[AudioService] Primary STT failed, trying fallback: \(error)")
            do {
                return try await sttFallback.transcribe(audioURL: audioURL)
            } catch {
                let transcriptionError = AudioError.transcriptionFailed(error)
                self.error = transcriptionError
                throw transcriptionError
            }
        }
    }

    /// Cancel current recording
    func cancelRecording() async {
        await recorder.cancelRecording()
    }

    // MARK: - Speech Synthesis & Playback

    /// Synthesize text to speech and play it
    /// - Parameters:
    ///   - text: Text to speak
    ///   - voiceID: Optional voice identifier
    func speak(text: String, voiceID: String? = nil) async throws {
        error = nil

        // Synthesize with primary service
        let audioData: Data
        do {
            audioData = try await ttsService.synthesize(text: text, voiceID: voiceID)
        } catch {
            // Try fallback service
            // swiftlint:disable:next no_print_statements
            print("[AudioService] Primary TTS failed, trying fallback: \(error)")
            do {
                audioData = try await ttsFallback.synthesize(text: text, voiceID: nil)
            } catch {
                let synthesisError = AudioError.synthesisFailed(error)
                self.error = synthesisError
                throw synthesisError
            }
        }

        // Play audio
        do {
            try await player.play(audioData: audioData)
        } catch {
            let playbackError = AudioError.playbackFailed(error)
            self.error = playbackError
            throw playbackError
        }
    }

    /// Stop current playback
    func stopSpeaking() {
        player.stop()
    }

    // MARK: Private

    // TTS Services
    private let ttsService: TTSService
    private let ttsFallback: TTSService

    // STT Services
    private let sttService: STTService
    private let sttFallback: STTService

    /// Configuration
    private let storage: AIConfigStorage
}
