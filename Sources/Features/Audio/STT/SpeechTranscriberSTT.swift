//
// SpeechTranscriberSTT.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation
@preconcurrency import Speech

/// Primary STT service using iOS 18+ on-device speech recognition
@available(iOS 18.0, macOS 15.0, *)
final class SpeechTranscriberSTT: STTService {
    // MARK: Lifecycle

    init?() {
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US")) else {
            return nil
        }
        self.recognizer = recognizer
    }

    // MARK: Internal

    var isAvailable: Bool {
        get async {
            recognizer.isAvailable && SFSpeechRecognizer.authorizationStatus() == .authorized
        }
    }

    var requiresNetwork: Bool {
        false // On-device transcription
    }

    func transcribe(audioURL: URL) async throws -> String {
        // Check authorization
        let authStatus = SFSpeechRecognizer.authorizationStatus()
        if authStatus == .notDetermined {
            let granted = await requestAuthorization()
            if !granted {
                throw AudioError.permissionDenied
            }
        } else if authStatus != .authorized {
            throw AudioError.permissionDenied
        }

        guard recognizer.isAvailable else {
            throw AudioError.serviceUnavailable("SpeechRecognizer")
        }

        // Create recognition request
        let request = SFSpeechURLRecognitionRequest(url: audioURL)
        request.shouldReportPartialResults = false

        return try await withCheckedThrowingContinuation { continuation in
            recognizer.recognitionTask(with: request) { result, error in
                if let error {
                    continuation.resume(throwing: AudioError.transcriptionFailed(error))
                    return
                }

                guard let result, result.isFinal else {
                    return
                }

                continuation.resume(returning: result.bestTranscription.formattedString)
            }
        }
    }

    // MARK: Private

    private let recognizer: SFSpeechRecognizer

    private func requestAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }
}
