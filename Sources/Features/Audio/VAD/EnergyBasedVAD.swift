//
// EnergyBasedVAD.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import AVFoundation
import Foundation
import OSLog

/// Simple energy/amplitude based Voice Activity Detection
/// Fallback implementation for iOS 17 and earlier
@MainActor
final class EnergyBasedVAD: VADService {
    // MARK: Lifecycle

    init() {}

    // MARK: Private

    private let logger = Logger(subsystem: "com.tenex.ios", category: "EnergyBasedVAD")

    // MARK: Internal

    var onSpeechStart: (@Sendable () -> Void)?
    var onSpeechEnd: (@Sendable () -> Void)?
    var onError: (@Sendable (Error) -> Void)?

    func start(audioEngine: AVAudioEngine) async throws {
        guard !self.isActive else {
            self.logger.warning("[start] Already active, ignoring")
            return
        }

        self.logger.info("[start] Starting VAD")

        #if !os(macOS)
            /// Configure audio session for VAD
            let session = AVAudioSession.sharedInstance()
            do {
                // Use .mixWithOthers to allow AVAudioRecorder to work alongside audio engine
                try session.setCategory(.playAndRecord, mode: .voiceChat, options: [.allowBluetooth, .defaultToSpeaker, .mixWithOthers])
                try session.setActive(true, options: .notifyOthersOnDeactivation)
                self.logger.info("[start] Audio session configured with mixWithOthers")
            } catch {
                self.logger.error("[start] Failed to configure audio session: \(error.localizedDescription)")
                throw VADError.initializationFailed(error)
            }
        #endif

        self.audioEngine = audioEngine

        // Install tap on input node
        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)

        self.logger
            .info(
                "[start] Installing tap - sampleRate=\(format.sampleRate), channels=\(format.channelCount)"
            )

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            Task { @MainActor [weak self] in
                self?.processAudioBuffer(buffer)
            }
        }

        // Start the audio engine to begin processing audio
        do {
            if !audioEngine.isRunning {
                try audioEngine.start()
                self.logger.info("[start] Audio engine started")
            } else {
                self.logger.info("[start] Audio engine already running")
            }
        } catch {
            self.logger.error("[start] Failed to start audio engine: \(error.localizedDescription)")
            throw VADError.initializationFailed(error)
        }

        self.isActive = true
        self.isSpeaking = false
        self.logger.info("[start] VAD started successfully")
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
    private let silenceDuration: TimeInterval = 0.8 // Time of silence before stopping (reduced from 1.5s)

    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        // Check if audio engine is still running
        guard let audioEngine = self.audioEngine, audioEngine.isRunning else {
            self.logger.warning("[processAudioBuffer] Audio engine not running, attempting restart")
            // Try to restart the engine
            if let audioEngine = self.audioEngine, !audioEngine.isRunning {
                do {
                    try audioEngine.start()
                    self.logger.info("[processAudioBuffer] Audio engine restarted")
                } catch {
                    self.logger.error("[processAudioBuffer] Failed to restart audio engine: \(error.localizedDescription)")
                }
            }
            return
        }

        guard let channelData = buffer.floatChannelData else {
            self.logger.warning("[processAudioBuffer] No channel data")
            return
        }

        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0 else {
            self.logger.warning("[processAudioBuffer] Empty buffer")
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

        // Log audio levels when speaking
        if self.isSpeaking || rms > self.speechThreshold {
            self.logger
                .debug(
                    "[processAudioBuffer] rms=\(String(format: "%.4f", rms)), speechThreshold=\(String(format: "%.4f", self.speechThreshold)), silenceThreshold=\(String(format: "%.4f", self.silenceThreshold)), isSpeaking=\(self.isSpeaking)"
                )
        }

        // Check for speech activity based on thresholds
        if !self.isSpeaking, rms > self.speechThreshold {
            // Speech detected - start speaking
            self.logger.info("[processAudioBuffer] Speech START detected")
            self.handleSpeechStart()
        } else if self.isSpeaking, rms < self.silenceThreshold {
            // Silence detected while speaking - start silence timer
            self.logger.info("[processAudioBuffer] Silence detected, starting timer")
            self.startSilenceTimer()
        } else if self.isSpeaking, rms > self.speechThreshold {
            // Still speaking - cancel silence timer
            if self.silenceTimer != nil {
                self.logger.info("[processAudioBuffer] Speech continues, cancelling silence timer")
            }
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

        self.logger.info("[handleSilenceTimeout] Speech END detected (silence timeout)")
        self.isSpeaking = false
        self.silenceTimer = nil
        self.onSpeechEnd?()
    }
}
