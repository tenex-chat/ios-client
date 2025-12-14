//
// SystemTTSService.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import AVFoundation
import Foundation
import TENEXCore

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
        let utterance = configureUtterance(text: text, voiceID: voiceID)
        return try await performSynthesis(utterance: utterance)
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

    private func configureUtterance(text: String, voiceID: String?) -> AVSpeechUtterance {
        let utterance = AVSpeechUtterance(string: text)

        if let voiceID = voiceID?.lowercased(),
           let identifier = voiceMapping[voiceID],
           let voice = AVSpeechSynthesisVoice(identifier: identifier) {
            utterance.voice = voice
        } else {
            utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        }

        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0

        return utterance
    }

    private func performSynthesis(utterance: AVSpeechUtterance) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            Task { @MainActor in
                do {
                    #if os(iOS)
                        let session = AVAudioSession.sharedInstance()
                        try session.setCategory(.playback, mode: .default)
                        try session.setActive(true)
                    #endif

                    var audioData = Data()
                    let delegate = SpeechSynthesizerDelegate(
                        onFinish: {
                            // swiftlint:disable:next no_print_statements
                            print("[SystemTTSService] Warning: Direct audio capture not implemented")
                            continuation.resume(returning: audioData)
                        },
                        onError: { error in
                            continuation.resume(throwing: error)
                        }
                    )

                    synthesizer.delegate = delegate
                    synthesizer.speak(utterance)

                    withExtendedLifetime(delegate) {}
                } catch {
                    continuation.resume(throwing: AudioError.synthesisFailed(error))
                }
            }
        }
    }
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
