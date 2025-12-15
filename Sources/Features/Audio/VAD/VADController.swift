//
// VADController.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import AVFoundation
import Foundation
import Observation

/// Observable controller managing VAD lifecycle and state
@MainActor
@Observable
public final class VADController {
    // MARK: Lifecycle

    /// Initialize VAD controller
    /// - Parameters:
    ///   - audioEngine: Audio engine to monitor
    ///   - sensitivity: Initial sensitivity (0.0-1.0)
    public init(audioEngine: AVAudioEngine, sensitivity: Double = 0.5) {
        self.audioEngine = audioEngine
        self.sensitivity = sensitivity

        // Select appropriate VAD implementation based on OS version
        if #available(iOS 18.0, macOS 15.0, *) {
            service = AppleSpeechDetectorVAD()
        } else {
            self.service = EnergyBasedVAD()
        }

        // Set initial sensitivity
        self.service.updateSensitivity(sensitivity)
    }

    deinit {
        Task { @MainActor in
            await stop()
        }
    }

    // MARK: Public

    /// Callback when speech starts
    public var onSpeechStart: (@Sendable () -> Void)?

    /// Callback when speech ends
    public var onSpeechEnd: (@Sendable () -> Void)?

    /// Start VAD
    public func start() async throws {
        guard !self.isActive else {
            return
        }

        self.error = nil

        // Set up VAD callbacks
        self.service.onSpeechStart = { [weak self] in
            Task { @MainActor [weak self] in
                await self?.handleSpeechStart()
            }
        }

        self.service.onSpeechEnd = { [weak self] in
            Task { @MainActor [weak self] in
                await self?.handleSpeechEnd()
            }
        }

        self.service.onError = { [weak self] vadError in
            Task { @MainActor [weak self] in
                self?.error = vadError.localizedDescription
            }
        }

        // Start the service
        do {
            try await self.service.start(audioEngine: self.audioEngine)
            self.isActive = true
        } catch {
            self.error = error.localizedDescription
            throw error
        }
    }

    /// Stop VAD
    public func stop() async {
        guard self.isActive else {
            return
        }

        await self.service.stop()
        self.isActive = false
        self.isListening = false
        self.isHolding = false
        self.error = nil
    }

    /// Pause VAD auto-stop (tap-to-hold override)
    public func pause() {
        guard self.isActive, !self.isHolding else {
            return
        }
        self.isHolding = true
    }

    /// Resume VAD auto-stop (release tap-to-hold)
    public func resume() {
        guard self.isActive, self.isHolding else {
            return
        }
        self.isHolding = false
    }

    /// Update VAD sensitivity
    /// - Parameter sensitivity: Sensitivity value (0.0-1.0)
    public func updateSensitivity(_ sensitivity: Double) {
        self.sensitivity = sensitivity
        self.service.updateSensitivity(sensitivity)
    }

    // MARK: Internal

    /// Whether VAD is currently active
    private(set) var isActive = false

    /// Whether speech is being detected (listening state)
    private(set) var isListening = false

    /// Whether user is holding the mic (tap-to-hold override)
    private(set) var isHolding = false

    /// Current error message if any
    private(set) var error: String?

    // MARK: Private

    private let audioEngine: AVAudioEngine
    private var service: VADService
    private var sensitivity: Double

    private func handleSpeechStart() async {
        // Don't trigger callbacks if holding
        guard !self.isHolding else {
            return
        }

        self.isListening = true
        self.onSpeechStart?()
    }

    private func handleSpeechEnd() async {
        // Don't trigger callbacks if holding
        guard !self.isHolding else {
            return
        }

        self.isListening = false
        self.onSpeechEnd?()
    }
}
