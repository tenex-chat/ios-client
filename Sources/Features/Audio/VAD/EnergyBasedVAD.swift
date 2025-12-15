//
// EnergyBasedVAD.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import AVFoundation
import Foundation

/// Simple energy/amplitude based Voice Activity Detection
/// Fallback implementation for iOS 17 and earlier
@MainActor
final class EnergyBasedVAD: VADService {
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

        #if !os(macOS)
            /// Configure audio session for VAD
            let session = AVAudioSession.sharedInstance()
            do {
                try session.setCategory(.playAndRecord, mode: .default)
                try session.setActive(true)
            } catch {
                throw VADError.initializationFailed(error)
            }
        #endif

        self.audioEngine = audioEngine

        // Install tap on input node
        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            Task { @MainActor [weak self] in
                self?.processAudioBuffer(buffer)
            }
        }

        // Start the audio engine to begin processing audio
        do {
            try audioEngine.start()
        } catch {
            throw VADError.initializationFailed(error)
        }

        self.isActive = true
        self.isSpeaking = false
    }

    func stop() async {
        guard self.isActive else {
            return
        }

        // Stop audio engine
        self.audioEngine?.stop()

        // Remove tap
        self.audioEngine?.inputNode.removeTap(onBus: 0)

        // Cleanup
        self.audioEngine = nil
        self.isActive = false
        self.isSpeaking = false
        self.currentLevel = 0.0
        self.silenceTimer?.invalidate()
        self.silenceTimer = nil
    }

    func updateSensitivity(_ sensitivity: Double) {
        self.sensitivity = sensitivity

        // Map sensitivity (0.0-1.0) to thresholds
        // Lower sensitivity = higher threshold (less sensitive to noise)
        // Higher sensitivity = lower threshold (more sensitive, may pick up noise)
        let inverted = 1.0 - sensitivity

        // Aggressive (high sensitivity): lower thresholds
        // Conservative (low sensitivity): higher thresholds
        self.speechThreshold = Float(0.015 + (inverted * 0.015)) // 0.015 - 0.03
        self.silenceThreshold = Float(0.008 + (inverted * 0.002)) // 0.008 - 0.01
    }

    // MARK: Private

    private var audioEngine: AVAudioEngine?
    private var isActive = false
    private var isSpeaking = false
    private var currentLevel: Float = 0.0
    private var silenceTimer: Timer?
    private var sensitivity = 0.5

    // Tunable parameters (adjusted by sensitivity)
    private var speechThreshold: Float = 0.02 // Amplitude threshold for speech
    private var silenceThreshold: Float = 0.01 // Amplitude threshold for silence
    private let silenceDuration: TimeInterval = 1.5 // Time of silence before stopping

    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else {
            return
        }

        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0 else {
            return
        }

        // Calculate RMS (Root Mean Square) energy
        var sum: Float = 0
        let samples = channelData[0]
        for frame in 0 ..< frameLength {
            let sample = samples[frame]
            sum += sample * sample
        }

        let rms = sqrt(sum / Float(frameLength))
        self.currentLevel = rms

        // Check for speech activity based on thresholds
        if !self.isSpeaking, rms > self.speechThreshold {
            // Speech detected - start speaking
            self.handleSpeechStart()
        } else if self.isSpeaking, rms < self.silenceThreshold {
            // Silence detected while speaking - start silence timer
            self.startSilenceTimer()
        } else if self.isSpeaking, rms > self.speechThreshold {
            // Still speaking - cancel silence timer
            self.cancelSilenceTimer()
        }
    }

    private func handleSpeechStart() {
        self.isSpeaking = true
        self.cancelSilenceTimer()
        self.onSpeechStart?()
    }

    private func startSilenceTimer() {
        // Don't start a new timer if one is already running
        guard self.silenceTimer == nil else {
            return
        }

        self.silenceTimer = Timer
            .scheduledTimer(withTimeInterval: self.silenceDuration, repeats: false) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.handleSilenceTimeout()
                }
            }
    }

    private func cancelSilenceTimer() {
        self.silenceTimer?.invalidate()
        self.silenceTimer = nil
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
