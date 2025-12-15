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

// MARK: - VODRecordingActor

/// Actor to serialize VOD file writes and prevent race conditions
actor VODRecordingActor {
    /// Initialize VOD recording with metadata
    func initializeRecording(at url: URL, metadata: [String: Any]) throws {
        let data = try JSONSerialization.data(withJSONObject: metadata, options: .prettyPrinted)
        try data.write(to: url)
    }

    /// Append a message to VOD recording
    func appendMessage(to url: URL, messageEntry: [String: Any]) throws {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return
        }

        // Read existing VOD data
        let existingData = try Data(contentsOf: url)
        var vodData = try JSONSerialization.jsonObject(with: existingData) as? [String: Any] ?? [:]

        // Get existing messages array
        var messages = vodData["messages"] as? [[String: Any]] ?? []

        // Append message
        messages.append(messageEntry)
        vodData["messages"] = messages

        // Write back to file atomically
        let updatedData = try JSONSerialization.data(withJSONObject: vodData, options: .prettyPrinted)
        try updatedData.write(to: url, options: .atomic)
    }

    /// Finalize VOD recording with end metadata
    func finalizeRecording(at url: URL, endTime: String, duration: TimeInterval) throws {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return
        }

        // Read existing VOD data
        let existingData = try Data(contentsOf: url)
        var vodData = try JSONSerialization.jsonObject(with: existingData) as? [String: Any] ?? [:]

        // Add end time and duration
        vodData["endTime"] = endTime
        vodData["duration"] = duration

        // Write back to file atomically
        let updatedData = try JSONSerialization.data(withJSONObject: vodData, options: .prettyPrinted)
        try updatedData.write(to: url, options: .atomic)
    }
}

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
        id: String? = nil,
        timestamp: Date? = nil,
        audioURL: URL? = nil
    ) {
        self.id = id ?? UUID().uuidString
        self.sender = sender
        self.content = content
        self.timestamp = timestamp ?? Date()
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

// swiftlint:disable type_body_length

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
    ///   - voiceID: Voice ID for TTS (from AgentVoiceConfigStorage)
    ///   - enableVOD: Whether to record the call for playback (Video/Voice on Demand)
    ///   - autoTTS: Whether to automatically speak agent responses
    ///   - onSendMessage: Callback to send message to agent (messageText, agentPubkey, tags in Nostr format)
    public init(
        audioService: AudioService,
        projectID: String,
        agent: ProjectAgent,
        voiceID: String? = nil,
        onSendMessage: @escaping (String, String, [[String]]) async throws -> Void,
        enableVOD: Bool = true,
        autoTTS: Bool = true
    ) {
        self.audioService = audioService
        self.projectID = projectID
        self.agent = agent
        self.voiceID = voiceID
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

    /// Voice ID for TTS (from AgentVoiceConfigStorage)
    public let voiceID: String?

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
        self.audioService.recorder.audioLevel
    }

    /// Whether the call is active
    public var isCallActive: Bool {
        self.state != .idle && self.state != .ended
    }

    /// Whether user can record
    public var canRecord: Bool {
        self.state == .listening
    }

    /// Whether send button should be enabled
    public var canSend: Bool {
        !self.currentTranscript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && self.state != .processingSTT
            && self.state != .waitingForAgent
    }

    // MARK: - Call Lifecycle

    /// Start the call
    public func startCall() async {
        guard self.state == .idle else {
            return
        }

        self.error = nil
        self.state = .connecting
        self.callStartTime = Date()

        // Start VOD recording if enabled
        if self.enableVOD {
            await self.startVODRecording()
        }

        // Transition to listening state
        self.state = .listening

        // Add system message
        let systemMessage = CallMessage(
            sender: .agent(pubkey: agent.pubkey, name: self.agent.name, voiceID: self.voiceID),
            content: Self.welcomeMessage
        )
        self.messages.append(systemMessage)

        // Speak welcome message if auto-TTS is enabled
        if self.autoTTS {
            self.state = .playingResponse
            self.ttsTask = Task {
                do {
                    try await self.audioService.speak(text: systemMessage.content, voiceID: self.voiceID)
                    if !Task.isCancelled {
                        self.state = .listening
                    }
                } catch {
                    if !Task.isCancelled {
                        self.error = error.localizedDescription
                        self.state = .listening
                    }
                }
            }
            await self.ttsTask?.value
        }
    }

    /// End the call
    public func endCall() async {
        // Cancel any recording
        if self.state == .recording {
            await self.audioService.cancelRecording()
        }

        // Cancel any ongoing TTS task
        self.ttsTask?.cancel()
        self.ttsTask = nil

        // Stop any playback
        self.audioService.stopSpeaking()

        // Stop VOD recording
        await self.stopVODRecording()

        // Update state
        self.state = .ended
        self.currentTranscript = ""

        // Calculate final duration
        if let startTime = callStartTime {
            self.callDuration = Date().timeIntervalSince(startTime)
        }
    }

    // MARK: - Voice Input

    /// Start recording user speech
    public func startRecording() async {
        guard self.canRecord else {
            return
        }

        self.error = nil
        self.state = .recording

        do {
            try await self.audioService.startRecording()
        } catch {
            self.error = error.localizedDescription
            self.state = .listening
        }
    }

    /// Stop recording and transcribe
    public func stopRecording() async {
        guard self.state == .recording else {
            return
        }

        self.state = .processingSTT

        do {
            let transcribedText = try await audioService.stopRecording()
            self.currentTranscript = transcribedText
            self.state = .listening
        } catch {
            self.error = error.localizedDescription
            self.state = .listening
        }
    }

    /// Toggle recording state (for push-to-talk)
    public func toggleRecording() async {
        if self.state == .recording {
            await self.stopRecording()
        } else if self.canRecord {
            await self.startRecording()
        }
    }

    /// Cancel current recording without transcribing
    public func cancelRecording() async {
        guard self.state == .recording else {
            return
        }

        await self.audioService.cancelRecording()
        self.state = .listening
    }

    // MARK: - Messaging

    /// Send the current transcript to the agent
    public func sendMessage() async {
        guard self.canSend else {
            return
        }

        let messageText = self.currentTranscript
        self.currentTranscript = ""
        self.error = nil

        // Add user message to conversation
        let userMessage = CallMessage(
            sender: .user,
            content: messageText
        )
        self.messages.append(userMessage)

        // Record to VOD if enabled
        if self.enableVOD, let recordingURL = vodRecordingURL {
            await self.recordMessageToVOD(message: userMessage, to: recordingURL)
        }

        self.state = .waitingForAgent

        do {
            // Send message with voice mode and call tags in proper Nostr format
            try await self.onSendMessage(messageText, self.agent.pubkey, [["mode", "voice"], ["type", "call"]])

            // Note: Agent response will be handled by handleAgentResponse()
        } catch {
            self.error = error.localizedDescription
            // Restore transcript on failure
            self.currentTranscript = messageText
            self.state = .listening
            // Remove the message since it failed to send
            // Verify it's still the last message before removing
            if self.messages.last?.id == userMessage.id {
                self.messages.removeLast()
            }
        }
    }

    /// Handle incoming agent response
    public func handleAgentResponse(_ text: String) async {
        guard self.isCallActive else {
            return
        }

        self.state = .playingResponse
        self.error = nil

        // Add agent message to conversation
        let agentMessage = CallMessage(
            sender: .agent(pubkey: agent.pubkey, name: self.agent.name, voiceID: self.voiceID),
            content: text
        )
        self.messages.append(agentMessage)

        // Record to VOD if enabled
        if self.enableVOD, let recordingURL = vodRecordingURL {
            await self.recordMessageToVOD(message: agentMessage, to: recordingURL)
        }

        // Play TTS if auto-TTS is enabled
        if self.autoTTS {
            self.ttsTask = Task {
                do {
                    try await self.audioService.speak(text: text, voiceID: self.voiceID)
                    if !Task.isCancelled {
                        self.state = .listening
                    }
                } catch {
                    if !Task.isCancelled {
                        self.error = error.localizedDescription
                        self.state = .listening
                    }
                }
            }
            await self.ttsTask?.value
        } else {
            self.state = .listening
        }
    }

    // MARK: - Playback Controls

    /// Stop current TTS playback
    public func stopPlayback() {
        self.audioService.stopSpeaking()
        if self.state == .playingResponse {
            self.state = .listening
        }
    }

    /// Toggle auto-TTS on/off
    public func toggleAutoTTS() {
        self.autoTTS.toggle()
    }

    /// Replay a specific message's audio
    public func replayMessage(_ messageID: String) async {
        guard let message = messages.first(where: { $0.id == messageID }) else {
            return
        }

        let previousState = self.state
        self.state = .playingResponse

        do {
            try await self.audioService.speak(text: message.content, voiceID: self.voiceID)
            self.state = previousState
        } catch {
            self.error = error.localizedDescription
            self.state = previousState
        }
    }

    // MARK: Private

    // MARK: - Constants

    private static let welcomeMessage = "Call started. How can I help you?"
    private static let vodRetentionDays = 30

    private let audioService: AudioService
    private let projectID: String
    private let onSendMessage: (String, String, [[String]]) async throws -> Void
    private var callStartTime: Date?
    private let logger = Logger(subsystem: "com.tenex.ios", category: "CallViewModel")
    private let vodActor = VODRecordingActor()
    private var ttsTask: Task<Void, Never>?

    // MARK: - VOD Directory Management

    /// Get the dedicated VOD recordings directory
    private nonisolated static func vodRecordingsDirectory() -> URL {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsURL.appendingPathComponent("VODRecordings", isDirectory: true)
    }

    /// Ensure VOD recordings directory exists
    private func ensureVODDirectory() throws {
        let vodDir = Self.vodRecordingsDirectory()
        if !FileManager.default.fileExists(atPath: vodDir.path) {
            try FileManager.default.createDirectory(at: vodDir, withIntermediateDirectories: true)
        }
    }

    /// Clean up old VOD recordings (older than retention period)
    private func cleanupOldVODRecordings() {
        Task.detached { [logger] in
            do {
                let vodDir = Self.vodRecordingsDirectory()
                guard FileManager.default.fileExists(atPath: vodDir.path) else {
                    return
                }

                let fileManager = FileManager.default
                let files = try fileManager.contentsOfDirectory(
                    at: vodDir,
                    includingPropertiesForKeys: [.creationDateKey],
                    options: [.skipsHiddenFiles]
                )

                let cutoffDate = Calendar.current.date(
                    byAdding: .day,
                    value: -Self.vodRetentionDays,
                    to: Date()
                ) ?? Date()

                for fileURL in files {
                    guard let attributes = try? fileManager.attributesOfItem(atPath: fileURL.path),
                          let creationDate = attributes[.creationDate] as? Date
                    else {
                        continue
                    }

                    if creationDate < cutoffDate {
                        try? fileManager.removeItem(at: fileURL)
                        logger.info("Deleted old VOD recording: \(fileURL.lastPathComponent)")
                    }
                }
            } catch {
                logger.error("Failed to cleanup old VOD recordings: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - VOD Recording

    /// Start VOD recording
    private func startVODRecording() async {
        guard self.enableVOD else {
            return
        }

        do {
            // Ensure VOD directory exists
            try self.ensureVODDirectory()

            // Clean up old recordings in background
            self.cleanupOldVODRecordings()

            // Create file in dedicated directory
            let vodDir = Self.vodRecordingsDirectory()
            let fileName = "call_\(projectID)_\(agent.pubkey)_\(Date().timeIntervalSince1970).json"
            let fileURL = vodDir.appendingPathComponent(fileName)

            self.vodRecordingURL = fileURL

            // Initialize VOD file with metadata using actor
            let metadata: [String: Any] = [
                "projectID": projectID,
                "agentPubkey": agent.pubkey,
                "agentName": self.agent.name,
                "startTime": ISO8601DateFormatter().string(from: Date()),
                "messages": [],
            ]

            try await self.vodActor.initializeRecording(at: fileURL, metadata: metadata)
        } catch {
            self.error = "Failed to start VOD recording: \(error.localizedDescription)"
            self.vodRecordingURL = nil
        }
    }

    /// Record a message to VOD file
    private func recordMessageToVOD(message: CallMessage, to url: URL) async {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return
        }

        do {
            // Create message entry
            let messageEntry: [String: Any] = [
                "id": message.id,
                "sender": message.sender == .user ? "user" : "agent",
                "content": message.content,
                "timestamp": ISO8601DateFormatter().string(from: message.timestamp),
            ]

            // Use actor to safely append message
            try await self.vodActor.appendMessage(to: url, messageEntry: messageEntry)
        } catch {
            // Silently fail - don't interrupt the call
            self.logger.error("Failed to record message to VOD: \(error.localizedDescription)")
        }
    }

    /// Stop VOD recording and finalize
    private func stopVODRecording() async {
        guard let url = vodRecordingURL else {
            return
        }

        do {
            let endTime = ISO8601DateFormatter().string(from: Date())
            try await self.vodActor.finalizeRecording(at: url, endTime: endTime, duration: self.callDuration)
        } catch {
            self.logger.error("Failed to finalize VOD recording: \(error.localizedDescription)")
        }
    }
}

// swiftlint:enable type_body_length
