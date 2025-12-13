//
//  VoiceModeViewModel.swift
//  TENEX
//
//  Created by Jules on 2024.
//

import Foundation
import Observation
import TENEXCore
import AVFoundation

@Observable
public final class VoiceModeViewModel: SpeechRecognizerDelegate {

    public enum VoiceState {
        case idle
        case listening
        case processing
        case speaking
        case error(String)
    }

    public var state: VoiceState = .idle
    public var transcription: String = ""
    public var waveformSamples: [Float] = Array(repeating: 0.1, count: 10)

    private let speechRecognizer: SpeechRecognizer
    private let ttsManager: TTSManagerProtocol

    // In a real app we would inject these
    public init(speechRecognizer: SpeechRecognizer = SpeechRecognizer(),
                ttsManager: TTSManagerProtocol = TTSManager()) {
        self.speechRecognizer = speechRecognizer
        self.ttsManager = ttsManager
        self.speechRecognizer.delegate = self
    }

    public func startSession() {
        Task {
            let authorized = await speechRecognizer.requestAuthorization()
            if authorized {
                await MainActor.run {
                    startListening()
                }
            } else {
                await MainActor.run {
                    state = .error("Microphone permission denied")
                }
            }
        }
    }

    public func stopSession() {
        if speechRecognizer.isRecording {
            speechRecognizer.stopRecording()
        }
        ttsManager.stop()
        state = .idle
    }

    public func toggleListening() {
        if speechRecognizer.isRecording {
            stopListening()
        } else {
            startListening()
        }
    }

    private func startListening() {
        do {
            try speechRecognizer.startRecording()
            state = .listening
            transcription = ""
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    private func stopListening() {
        speechRecognizer.stopRecording()
        // Here we would normally send the transcription to the agent
        // For now, we'll just echo it back via TTS to demonstrate flow
        if !transcription.isEmpty {
            processTranscription(transcription)
        } else {
            state = .idle
        }
    }

    private func processTranscription(_ text: String) {
        state = .processing

        // Simulate agent processing delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self = self else { return }
            self.state = .speaking
            self.ttsManager.speak("I heard you say: \(text)")

            // In a real flow, we would wait for TTS to finish before listening again
            // This requires TTS delegate callback handling which we haven't fully wired up in ViewModel yet
        }
    }

    // MARK: - SpeechRecognizerDelegate

    public func speechRecognizer(_ recognizer: SpeechRecognizer, didRecognizeText text: String, isFinal: Bool) {
        self.transcription = text

        // Update waveform (simulated for now)
        var newSamples = self.waveformSamples
        newSamples.removeFirst()
        newSamples.append(Float.random(in: 0.1...1.0))
        self.waveformSamples = newSamples

        if isFinal {
           stopListening()
        }
    }

    public func speechRecognizer(_ recognizer: SpeechRecognizer, didFailWithError error: Error) {
        state = .error(error.localizedDescription)
    }

    public func speechRecognizerDidDetectVoice(_ recognizer: SpeechRecognizer) {
        // Can update UI to show voice detected
    }

    public func speechRecognizerDidStopRecording(_ recognizer: SpeechRecognizer) {
        if case .listening = state {
            state = .idle
        }
    }
}
