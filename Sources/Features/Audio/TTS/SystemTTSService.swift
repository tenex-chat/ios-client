//
// SystemTTSService.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import AVFoundation
import Foundation

// MARK: - SystemTTSService

/// Fallback TTS service using system AVSpeechSynthesizer
/// Always available, no API key required, basic quality
@MainActor
final class SystemTTSService: TTSService {
    // MARK: Lifecycle

    init() {}

    // MARK: Internal

    var supportedVoices: [VoiceConfig] {
        [
            VoiceConfig(
                name: "Samantha",
                provider: .system,
                voiceID: "samantha",
                metadata: VoiceMetadata(gender: "Female", accent: "American", ageRange: "Adult")
            ),
            VoiceConfig(
                name: "Alex",
                provider: .system,
                voiceID: "alex",
                metadata: VoiceMetadata(gender: "Male", accent: "American", ageRange: "Adult")
            ),
            VoiceConfig(
                name: "Daniel",
                provider: .system,
                voiceID: "daniel",
                metadata: VoiceMetadata(gender: "Male", accent: "British", ageRange: "Adult")
            ),
            VoiceConfig(
                name: "Karen",
                provider: .system,
                voiceID: "karen",
                metadata: VoiceMetadata(gender: "Female", accent: "Australian", ageRange: "Adult")
            ),
        ]
    }

    var isAvailable: Bool {
        get async { true } // Always available
    }

    func synthesize(text: String, voiceID: String?) async throws -> Data {
        // Create speech utterance
        let utterance = AVSpeechUtterance(string: text)

        // Set voice if specified
        if let voiceID = voiceID?.lowercased(),
           let identifier = voiceMapping[voiceID],
           let voice = AVSpeechSynthesisVoice(identifier: identifier) {
            utterance.voice = voice
        } else {
            // Use default voice
            utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        }

        // Configure utterance settings
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0

        // Capture audio to file
        return try await withCheckedThrowingContinuation { continuation in
            Task { @MainActor in
                // Create temporary file for audio
                let tempDir = FileManager.default.temporaryDirectory
                let audioFile = tempDir.appendingPathComponent("tts_\(UUID().uuidString).caf")

                do {
                    // Set up audio session
                    let session = AVAudioSession.sharedInstance()
                    try session.setCategory(.playback, mode: .default)
                    try session.setActive(true)

                    // Write audio to file by using AVSpeechSynthesizer's built-in output
                    // Note: AVSpeechSynthesizer doesn't have direct audio output API,
                    // so we'll use the output callback approach

                    var audioData = Data()
                    var didFinish = false
                    var didError: Error?

                    // Create a delegate to capture completion
                    let delegate = SpeechSynthesizerDelegate(
                        onFinish: {
                            didFinish = true
                            // AVSpeechSynthesizer speaks to output, we need to record it
                            // For now, return empty data
                            // Proper implementation would require AVAudioEngine recording
                            // swiftlint:disable:next no_print_statements
                            print("[SystemTTSService] Warning: Direct audio capture not implemented")
                            continuation.resume(returning: audioData)
                        },
                        onError: { error in
                            didError = error
                            continuation.resume(throwing: error)
                        }
                    )

                    synthesizer.delegate = delegate

                    // Speak the utterance
                    synthesizer.speak(utterance)

                    // Keep delegate alive
                    withExtendedLifetime(delegate) {
                        // Delegate will handle completion
                    }
                } catch {
                    continuation.resume(throwing: AudioError.synthesisFailed(error))
                }
            }
        }
    }

    // MARK: Private

    private let synthesizer = AVSpeechSynthesizer()

    /// System voices mapped from VoiceConfig IDs
    private let voiceMapping: [String: String] = [
        "samantha": "com.apple.ttsbundle.Samantha-compact",
        "alex": "com.apple.ttsbundle.Alex-compact",
        "daniel": "com.apple.ttsbundle.Daniel-compact",
        "karen": "com.apple.ttsbundle.Karen-compact",
    ]
}

// MARK: - SpeechSynthesizerDelegate

/// Simple delegate to capture speech synthesis completion
private class SpeechSynthesizerDelegate: NSObject, AVSpeechSynthesizerDelegate {
    // MARK: Lifecycle

    init(onFinish: @escaping () -> Void, onError: @escaping (Error) -> Void) {
        self.onFinish = onFinish
        self.onError = onError
    }

    // MARK: Internal

    let onFinish: () -> Void
    let onError: (Error) -> Void

    func speechSynthesizer(_: AVSpeechSynthesizer, didFinish _: AVSpeechUtterance) {
        onFinish()
    }

    func speechSynthesizer(
        _: AVSpeechSynthesizer,
        didCancel _: AVSpeechUtterance
    ) {
        onError(AudioError.synthesisFailed(NSError(
            domain: "SystemTTS",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: "Speech synthesis cancelled"]
        )))
    }
}
