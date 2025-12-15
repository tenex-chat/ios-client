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

    /// Initialize the audio service
    /// - Parameters:
    ///   - storage: AI configuration storage
    ///   - capabilityDetector: Detector for AI capabilities
    public init(storage: AIConfigStorage, capabilityDetector: AICapabilityDetector) {
        self.storage = storage
        self.recorder = AudioRecorder()
        self.player = AudioPlayer()

        // Initialize TTS services based on user's provider preference
        let config = try? storage.load()
        let preferredProvider = config?.ttsSettings.provider ?? .system

        switch preferredProvider {
        case .elevenlabs:
            if let apiKey = try? storage.loadTTSAPIKey(for: .elevenlabs), !apiKey.isEmpty {
                self.ttsService = ElevenLabsTTSService(apiKey: apiKey)
            } else {
                // Fall back to system if no API key
                self.ttsService = SystemTTSService()
            }
        case .openai:
            // OpenAI TTS not implemented yet, fall back to system
            self.ttsService = SystemTTSService()
        case .system:
            self.ttsService = SystemTTSService()
        }
        self.ttsFallback = SystemTTSService()

        // Initialize STT services
        // Primary: SpeechTranscriber (iOS 18+) or WhisperKit (fallback)
        // Fallback: WhisperKit
        if #available(iOS 18.0, macOS 15.0, *),
           capabilityDetector.isSpeechTranscriberAvailable(),
           let speechTranscriber = SpeechTranscriberSTT() {
            sttService = speechTranscriber
        } else {
            self.sttService = WhisperKitSTT()
        }
        self.sttFallback = WhisperKitSTT()
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
        if self.ttsService is ElevenLabsTTSService {
            "ElevenLabs"
        } else {
            "System"
        }
    }

    /// Get current STT provider name
    var currentSTTProvider: String {
        if #available(iOS 18.0, macOS 15.0, *), self.sttService is SpeechTranscriberSTT {
            "SpeechTranscriber"
        } else {
            "WhisperKit"
        }
    }

    /// Check if TTS is available
    var isTTSAvailable: Bool {
        get async {
            await self.ttsService.isAvailable
        }
    }

    /// Check if STT is available
    var isSTTAvailable: Bool {
        get async {
            await self.sttService.isAvailable
        }
    }

    // MARK: - Recording & Transcription

    /// Start recording audio
    func startRecording() async throws {
        self.error = nil
        try await self.recorder.startRecording()
    }

    /// Stop recording and transcribe the audio
    /// - Returns: Transcribed text
    func stopRecording() async throws -> String {
        self.error = nil

        // Stop recording and get audio file
        let audioURL = try await recorder.stopRecording()

        // Transcribe with primary service
        do {
            return try await self.sttService.transcribe(audioURL: audioURL)
        } catch {
            // Try fallback service
            // swiftlint:disable:next no_print_statements
            print("[AudioService] Primary STT failed, trying fallback: \(error)")
            do {
                return try await self.sttFallback.transcribe(audioURL: audioURL)
            } catch {
                let transcriptionError = AudioError.transcriptionFailed(error)
                self.error = transcriptionError
                throw transcriptionError
            }
        }
    }

    /// Cancel current recording
    func cancelRecording() async {
        await self.recorder.cancelRecording()
    }

    // MARK: - Speech Synthesis & Playback

    /// Synthesize text to audio data (for caching before playback)
    /// - Parameters:
    ///   - text: Text to synthesize
    ///   - voiceID: Optional voice identifier
    /// - Returns: Audio data
    func synthesize(text: String, voiceID: String? = nil) async throws -> Data {
        self.error = nil

        // Synthesize with primary service
        do {
            return try await self.ttsService.synthesize(text: text, voiceID: voiceID)
        } catch {
            // Try fallback service
            // swiftlint:disable:next no_print_statements
            print("[AudioService] Primary TTS failed, trying fallback: \(error)")
            do {
                return try await self.ttsFallback.synthesize(text: text, voiceID: nil)
            } catch {
                let synthesisError = AudioError.synthesisFailed(error)
                self.error = synthesisError
                throw synthesisError
            }
        }
    }

    /// Play pre-synthesized audio data
    /// - Parameter audioData: Audio data to play
    func play(audioData: Data) async throws {
        self.error = nil

        do {
            try await self.player.play(audioData: audioData)
        } catch {
            let playbackError = AudioError.playbackFailed(error)
            self.error = playbackError
            throw playbackError
        }
    }

    /// Synthesize text to speech and play it
    /// - Parameters:
    ///   - text: Text to speak
    ///   - voiceID: Optional voice identifier
    func speak(text: String, voiceID: String? = nil) async throws {
        let audioData = try await synthesize(text: text, voiceID: voiceID)
        try await play(audioData: audioData)
    }

    /// Stop current playback
    func stopSpeaking() {
        self.player.stop()
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
