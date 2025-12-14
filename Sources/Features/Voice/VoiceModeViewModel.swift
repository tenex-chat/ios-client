//
// VoiceModeViewModel.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation
import Observation
import TENEXCore

// MARK: - VoiceCallState

/// Voice call state machine
public enum VoiceCallState: Sendable, Equatable {
    /// Idle - waiting for user to speak
    case idle
    /// Recording user speech
    case recording
    /// Processing speech-to-text
    case processing
    /// Playing agent TTS response
    case playing
}

// MARK: - VoiceModeViewModel

/// View model for voice mode conversation
/// Orchestrates recording, transcription, agent messaging, and TTS playback
@MainActor
@Observable
public final class VoiceModeViewModel {
    // MARK: Lifecycle

    /// Initialize voice mode view model
    /// - Parameters:
    ///   - audioService: Audio service for recording and playback
    ///   - projectID: Project identifier
    ///   - agents: Available online agents
    ///   - onSendMessage: Callback to send message to agent
    public init(
        audioService: AudioService,
        projectID: String,
        agents: [ProjectAgent],
        onSendMessage: @escaping (String, String, [String]) async throws -> Void
    ) {
        self.audioService = audioService
        self.projectID = projectID
        self.agents = agents
        self.onSendMessage = onSendMessage

        // Select first agent by default
        selectedAgent = agents.first
    }

    // MARK: Public

    /// Current call state
    public private(set) var state: VoiceCallState = .idle

    /// Current transcript from STT
    public private(set) var transcript = ""

    /// Error message if any
    public private(set) var error: String?

    /// Selected agent for the call
    public var selectedAgent: ProjectAgent?

    /// Available agents
    public let agents: [ProjectAgent]

    /// Audio level for visualization (0.0 to 1.0)
    public var audioLevel: Double {
        audioService.recorder.audioLevel
    }

    /// Whether the call is active (not idle)
    public var isCallActive: Bool {
        state != .idle || !transcript.isEmpty
    }

    /// Whether send button should be enabled
    public var canSend: Bool {
        !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && state != .processing
            && state != .playing
    }

    /// Start recording (voice activity detected)
    public func startRecording() async {
        guard state == .idle else {
            return
        }

        error = nil
        state = .recording

        do {
            try await audioService.startRecording()
        } catch {
            self.error = error.localizedDescription
            state = .idle
        }
    }

    /// Stop recording and transcribe
    public func stopRecording() async {
        guard state == .recording else {
            return
        }

        state = .processing

        do {
            let transcribedText = try await audioService.stopRecording()
            transcript = transcribedText
            state = .idle
        } catch {
            self.error = error.localizedDescription
            state = .idle
        }
    }

    /// Toggle recording state (for push-to-talk)
    public func toggleRecording() async {
        if state == .recording {
            await stopRecording()
        } else if state == .idle {
            await startRecording()
        }
    }

    /// Cancel current recording without transcribing
    public func cancelRecording() async {
        guard state == .recording else {
            return
        }

        await audioService.cancelRecording()
        state = .idle
    }

    /// Send the current transcript to the selected agent
    public func sendMessage() async {
        guard canSend else {
            return
        }
        guard let agent = selectedAgent else {
            error = "No agent selected"
            return
        }

        let messageText = transcript
        transcript = ""
        error = nil

        do {
            // Send message with voice mode tag
            try await onSendMessage(messageText, agent.pubkey, ["mode", "voice"])
        } catch {
            self.error = error.localizedDescription
            // Restore transcript on failure
            transcript = messageText
        }
    }

    /// Handle incoming agent response - play TTS
    public func handleAgentResponse(_ text: String, voiceID: String? = nil) async {
        guard state == .idle else {
            return
        }

        state = .playing
        error = nil

        do {
            try await audioService.speak(text: text, voiceID: voiceID)
            state = .idle
        } catch {
            self.error = error.localizedDescription
            state = .idle
        }
    }

    /// Stop current TTS playback
    public func stopPlayback() {
        audioService.stopSpeaking()
        if state == .playing {
            state = .idle
        }
    }

    /// End the voice call and clean up
    public func endCall() async {
        // Cancel any recording
        if state == .recording {
            await audioService.cancelRecording()
        }

        // Stop any playback
        audioService.stopSpeaking()

        // Reset state
        state = .idle
        transcript = ""
        error = nil
    }

    /// Clear the current transcript
    public func clearTranscript() {
        transcript = ""
    }

    /// Select a different agent
    public func selectAgent(_ agent: ProjectAgent) {
        selectedAgent = agent
    }

    // MARK: Private

    private let audioService: AudioService
    private let projectID: String
    private let onSendMessage: (String, String, [String]) async throws -> Void
}
