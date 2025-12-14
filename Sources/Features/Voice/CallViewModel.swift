//
// CallViewModel.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import AVFoundation
import Foundation
import Observation
import OSLog
import TENEXCore

// MARK: - CallState

/// Enhanced call state machine with VOD support
public enum CallState: Sendable, Equatable {
    /// Idle - call not started
    case idle
    /// Connecting to agent
    case connecting
    /// Active call - listening for user speech
    case listening
    /// Recording user speech
    case recording
    /// Processing speech-to-text
    case processingSTT
    /// Waiting for agent response
    case waitingForAgent
    /// Playing agent TTS response
    case playingResponse
    /// Call ended
    case ended
}

// MARK: - CallMessage

/// Represents a message in the call conversation
public struct CallMessage: Identifiable, Sendable {
    // MARK: Lifecycle

    public init(
        sender: CallParticipant,
        content: String,
        id: String = UUID().uuidString,
        timestamp: Date = Date(),
        audioURL: URL? = nil
    ) {
        self.id = id
        self.sender = sender
        self.content = content
        self.timestamp = timestamp
        self.audioURL = audioURL
    }

    // MARK: Public

    public let id: String
    public let sender: CallParticipant
    public let content: String
    public let timestamp: Date
    public var audioURL: URL?
}

// MARK: - CallParticipant

/// Represents a participant in the call
public enum CallParticipant: Sendable, Equatable {
    case user
    case agent(pubkey: String, name: String, voiceID: String?)

    // MARK: Public

    public var displayName: String {
        switch self {
        case .user:
            "You"
        case let .agent(_, name, _):
            name
        }
    }
}

// MARK: - CallViewModel

/// Enhanced view model for agent calls with auto-TTS, STT, and VOD recording
@MainActor
@Observable
public final class CallViewModel {
    // MARK: Lifecycle

    /// Initialize call view model
    /// - Parameters:
    ///   - audioService: Audio service for recording, TTS, and playback
    ///   - projectID: Project identifier
    ///   - agent: Agent to call
    ///   - enableVOD: Whether to record the call for playback (Video/Voice on Demand)
    ///   - autoTTS: Whether to automatically speak agent responses
    ///   - onSendMessage: Callback to send message to agent
    public init(
        audioService: AudioService,
        projectID: String,
        agent: ProjectAgent,
        onSendMessage: @escaping (String, String, [String]) async throws -> Void,
        enableVOD: Bool = true,
        autoTTS: Bool = true
    ) {
        self.audioService = audioService
        self.projectID = projectID
        self.agent = agent
        self.enableVOD = enableVOD
        self.autoTTS = autoTTS
        self.onSendMessage = onSendMessage
    }

    // MARK: Public

    /// Current call state
    public private(set) var state: CallState = .idle

    /// Current transcript from STT
    public private(set) var currentTranscript = ""

    /// Call messages (conversation history)
    public private(set) var messages: [CallMessage] = []

    /// Error message if any
    public private(set) var error: String?

    /// Agent in the call
    public let agent: ProjectAgent

    /// Whether VOD recording is enabled
    public let enableVOD: Bool

    /// Whether auto-TTS is enabled
    public private(set) var autoTTS: Bool

    /// Call duration
    public private(set) var callDuration: TimeInterval = 0.0

    /// VOD recording URL (if recording is enabled)
    public private(set) var vodRecordingURL: URL?

    /// Audio level for visualization (0.0 to 1.0)
    public var audioLevel: Double {
        audioService.recorder.audioLevel
    }

    /// Whether the call is active
    public var isCallActive: Bool {
        state != .idle && state != .ended
    }

    /// Whether user can record
    public var canRecord: Bool {
        state == .listening
    }

    /// Whether send button should be enabled
    public var canSend: Bool {
        !currentTranscript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && state != .processingSTT
            && state != .waitingForAgent
    }

    // MARK: - Call Lifecycle

    /// Start the call
    public func startCall() async {
        guard state == .idle else {
            return
        }

        error = nil
        state = .connecting
        callStartTime = Date()

        // Start VOD recording if enabled
        if enableVOD {
            await startVODRecording()
        }

        // Transition to listening state
        state = .listening

        // Add system message
        let systemMessage = CallMessage(
            sender: .agent(pubkey: agent.pubkey, name: agent.name, voiceID: agent.voiceID),
            content: "Call started. How can I help you?"
        )
        messages.append(systemMessage)

        // Speak welcome message if auto-TTS is enabled
        if autoTTS {
            state = .playingResponse
            do {
                try await audioService.speak(text: systemMessage.content, voiceID: agent.voiceID)
                state = .listening
            } catch {
                self.error = error.localizedDescription
                state = .listening
            }
        }
    }

    /// End the call
    public func endCall() async {
        // Cancel any recording
        if state == .recording {
            await audioService.cancelRecording()
        }

        // Stop any playback
        audioService.stopSpeaking()

        // Stop VOD recording
        await stopVODRecording()

        // Update state
        state = .ended
        currentTranscript = ""

        // Calculate final duration
        if let startTime = callStartTime {
            callDuration = Date().timeIntervalSince(startTime)
        }
    }

    // MARK: - Voice Input

    /// Start recording user speech
    public func startRecording() async {
        guard canRecord else {
            return
        }

        error = nil
        state = .recording

        do {
            try await audioService.startRecording()
        } catch {
            self.error = error.localizedDescription
            state = .listening
        }
    }

    /// Stop recording and transcribe
    public func stopRecording() async {
        guard state == .recording else {
            return
        }

        state = .processingSTT

        do {
            let transcribedText = try await audioService.stopRecording()
            currentTranscript = transcribedText
            state = .listening
        } catch {
            self.error = error.localizedDescription
            state = .listening
        }
    }

    /// Toggle recording state (for push-to-talk)
    public func toggleRecording() async {
        if state == .recording {
            await stopRecording()
        } else if canRecord {
            await startRecording()
        }
    }

    /// Cancel current recording without transcribing
    public func cancelRecording() async {
        guard state == .recording else {
            return
        }

        await audioService.cancelRecording()
        state = .listening
    }

    // MARK: - Messaging

    /// Send the current transcript to the agent
    public func sendMessage() async {
        guard canSend else {
            return
        }

        let messageText = currentTranscript
        currentTranscript = ""
        error = nil

        // Add user message to conversation
        let userMessage = CallMessage(
            sender: .user,
            content: messageText
        )
        messages.append(userMessage)

        // Record to VOD if enabled
        if enableVOD, let recordingURL = vodRecordingURL {
            await recordMessageToVOD(message: userMessage, to: recordingURL)
        }

        state = .waitingForAgent

        do {
            // Send message with voice mode and call tags
            try await onSendMessage(messageText, agent.pubkey, ["mode", "voice", "type", "call"])

            // Note: Agent response will be handled by handleAgentResponse()
        } catch {
            self.error = error.localizedDescription
            // Restore transcript on failure
            currentTranscript = messageText
            state = .listening
            // Remove the message since it failed to send
            if let index = messages.lastIndex(where: { $0.id == userMessage.id }) {
                messages.remove(at: index)
            }
        }
    }

    /// Handle incoming agent response
    public func handleAgentResponse(_ text: String) async {
        guard isCallActive else {
            return
        }

        state = .playingResponse
        error = nil

        // Add agent message to conversation
        let agentMessage = CallMessage(
            sender: .agent(pubkey: agent.pubkey, name: agent.name, voiceID: agent.voiceID),
            content: text
        )
        messages.append(agentMessage)

        // Record to VOD if enabled
        if enableVOD, let recordingURL = vodRecordingURL {
            await recordMessageToVOD(message: agentMessage, to: recordingURL)
        }

        // Play TTS if auto-TTS is enabled
        if autoTTS {
            do {
                try await audioService.speak(text: text, voiceID: agent.voiceID)
                state = .listening
            } catch {
                self.error = error.localizedDescription
                state = .listening
            }
        } else {
            state = .listening
        }
    }

    // MARK: - Playback Controls

    /// Stop current TTS playback
    public func stopPlayback() {
        audioService.stopSpeaking()
        if state == .playingResponse {
            state = .listening
        }
    }

    /// Toggle auto-TTS on/off
    public func toggleAutoTTS() {
        autoTTS.toggle()
    }

    /// Replay a specific message's audio
    public func replayMessage(_ messageID: String) async {
        guard let message = messages.first(where: { $0.id == messageID }) else {
            return
        }

        let previousState = state
        state = .playingResponse

        do {
            try await audioService.speak(text: message.content, voiceID: agent.voiceID)
            state = previousState
        } catch {
            self.error = error.localizedDescription
            state = previousState
        }
    }

    // MARK: Private

    private let audioService: AudioService
    private let projectID: String
    private let onSendMessage: (String, String, [String]) async throws -> Void
    private var callStartTime: Date?
    private let logger = Logger(subsystem: "com.tenex.ios", category: "CallViewModel")

    // MARK: - VOD Recording

    /// Start VOD recording
    private func startVODRecording() async {
        guard enableVOD else {
            return
        }

        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "call_\(projectID)_\(agent.pubkey)_\(Date().timeIntervalSince1970).json"
        let fileURL = tempDir.appendingPathComponent(fileName)

        vodRecordingURL = fileURL

        // Initialize VOD file with metadata
        let metadata: [String: Any] = [
            "projectID": projectID,
            "agentPubkey": agent.pubkey,
            "agentName": agent.name,
            "startTime": ISO8601DateFormatter().string(from: Date()),
            "messages": [],
        ]

        do {
            let data = try JSONSerialization.data(withJSONObject: metadata, options: .prettyPrinted)
            try data.write(to: fileURL)
        } catch {
            self.error = "Failed to start VOD recording: \(error.localizedDescription)"
            vodRecordingURL = nil
        }
    }

    /// Record a message to VOD file
    private func recordMessageToVOD(message: CallMessage, to url: URL) async {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return
        }

        do {
            // Read existing VOD data
            let existingData = try Data(contentsOf: url)
            var vodData = try JSONSerialization.jsonObject(with: existingData) as? [String: Any] ?? [:]

            // Get existing messages array
            var messages = vodData["messages"] as? [[String: Any]] ?? []

            // Create message entry
            let messageEntry: [String: Any] = [
                "id": message.id,
                "sender": message.sender == .user ? "user" : "agent",
                "content": message.content,
                "timestamp": ISO8601DateFormatter().string(from: message.timestamp),
            ]

            // Append message
            messages.append(messageEntry)
            vodData["messages"] = messages

            // Write back to file
            let updatedData = try JSONSerialization.data(withJSONObject: vodData, options: .prettyPrinted)
            try updatedData.write(to: url)
        } catch {
            // Silently fail - don't interrupt the call
            logger.error("Failed to record message to VOD: \(error.localizedDescription)")
        }
    }

    /// Stop VOD recording and finalize
    private func stopVODRecording() async {
        guard let url = vodRecordingURL else {
            return
        }

        do {
            // Read existing VOD data
            let existingData = try Data(contentsOf: url)
            var vodData = try JSONSerialization.jsonObject(with: existingData) as? [String: Any] ?? [:]

            // Add end time and duration
            vodData["endTime"] = ISO8601DateFormatter().string(from: Date())
            vodData["duration"] = callDuration

            // Write back to file
            let updatedData = try JSONSerialization.data(withJSONObject: vodData, options: .prettyPrinted)
            try updatedData.write(to: url)
        } catch {
            logger.error("Failed to finalize VOD recording: \(error.localizedDescription)")
        }
    }
}
