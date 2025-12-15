//
// AppleSpeechDetectorVAD.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import AVFoundation
import Foundation
import Speech

/// Voice Activity Detection using Apple's native SpeechDetector (iOS 18+/macOS 15+)
@available(iOS 18.0, macOS 15.0, *)
@MainActor
final class AppleSpeechDetectorVAD: VADService {
    // MARK: Lifecycle

    init() {}

    deinit {
        Task { @MainActor in
            await stop()
        }
    }

    // MARK: Internal

    var onSpeechStart: (@Sendable () -> Void)?
    var onSpeechEnd: (@Sendable () -> Void)?
    var onError: (@Sendable (Error) -> Void)?

    func start(audioEngine: AVAudioEngine) async throws {
        guard !self.isActive else {
            return
        }

        // Create speech detector
        do {
            self.speechDetector = try SpeechDetector()
        } catch {
            throw VADError.initializationFailed(error)
        }

        guard self.speechDetector != nil else {
            throw VADError.serviceUnavailable
        }

        // Store audio engine reference
        self.audioEngine = audioEngine

        // Install tap on input node
        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            Task { @MainActor [weak self] in
                await self?.processAudioBuffer(buffer)
            }
        }

        self.isActive = true
        self.isSpeaking = false
    }

    func stop() async {
        guard self.isActive else {
            return
        }

        // Remove tap
        self.audioEngine?.inputNode.removeTap(onBus: 0)

        // Cleanup
        self.speechDetector = nil
        self.audioEngine = nil
        self.isActive = false
        self.isSpeaking = false
        self.silenceTimer?.invalidate()
        self.silenceTimer = nil
    }

    func updateSensitivity(_ sensitivity: Double) {
        // Apple SpeechDetector doesn't expose sensitivity controls
        // This is a no-op for the native implementation
        self.sensitivity = sensitivity
    }

    // MARK: Private

    private var speechDetector: SpeechDetector?
    private var audioEngine: AVAudioEngine?
    private var isActive = false
    private var isSpeaking = false
    private var sensitivity = 0.5
    private var silenceTimer: Timer?

    /// Silence duration before triggering speech end (in seconds)
    private let silenceDuration: TimeInterval = 1.5

    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) async {
        guard let detector = speechDetector else {
            return
        }

        do {
            // Analyze buffer through detector
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                detector.analyze(audioBuffer: buffer) { [weak self] result in
                    Task { @MainActor [weak self] in
                        guard let self else {
                            continuation.resume()
                            return
                        }

                        switch result.voiceActivity {
                        case .speech:
                            self.handleSpeechDetected()
                        case .silence:
                            self.handleSilenceDetected()
                        @unknown default:
                            break
                        }
                        continuation.resume()
                    }
                }
            }
        } catch {
            self.onError?(VADError.processingFailed(error))
        }
    }

    private func handleSpeechDetected() {
        // Cancel any pending silence timer
        self.silenceTimer?.invalidate()
        self.silenceTimer = nil

        // Trigger speech start if not already speaking
        if !self.isSpeaking {
            self.isSpeaking = true
            self.onSpeechStart?()
        }
    }

    private func handleSilenceDetected() {
        guard self.isSpeaking else {
            return
        }

        // Start silence timer if not already running
        if self.silenceTimer == nil {
            self.silenceTimer = Timer
                .scheduledTimer(withTimeInterval: self.silenceDuration, repeats: false) { [weak self] _ in
                    Task { @MainActor [weak self] in
                        self?.handleSilenceTimeout()
                    }
                }
        }
    }

    private func handleSilenceTimeout() {
        guard self.isSpeaking else {
            return
        }

        self.isSpeaking = false
        self.silenceTimer = nil
        self.onSpeechEnd?()
    }
}
