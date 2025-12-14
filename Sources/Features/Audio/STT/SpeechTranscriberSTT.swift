//
// SpeechTranscriberSTT.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation
import Speech

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
        guard authStatus == .authorized else {
            if authStatus == .notDetermined {
                // Request permission
                let granted = await SFSpeechRecognizer.requestAuthorization() == .authorized
                guard granted else {
                    throw AudioError.permissionDenied
                }
            } else {
                throw AudioError.permissionDenied
            }
        }

        guard recognizer.isAvailable else {
            throw AudioError.serviceUnavailable("SpeechRecognizer")
        }

        do {
            // Use new iOS 18 async API
            let transcription = try await recognizer.transcription(from: audioURL)
            return transcription.formattedString
        } catch {
            throw AudioError.transcriptionFailed(error)
        }
    }

    // MARK: Private

    private let recognizer: SFSpeechRecognizer
}
