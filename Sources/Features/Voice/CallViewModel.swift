//
// CallViewModel.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import AVFoundation
import Foundation
import NDKSwiftCore
import Observation
import OSLog
import TENEXCore

// MARK: - CallViewModel

// swiftlint:disable type_body_length file_length

/// Enhanced view model for agent calls with auto-TTS, STT, and VOD recording
@MainActor
@Observable
public final class CallViewModel {
    // MARK: Lifecycle

    /// Initialize call view model
    /// - Parameters:
    ///   - audioService: Audio service for recording, TTS, and playback
    ///   - ndk: NDK instance for conversation subscriptions
    ///   - projectID: Project identifier
    ///   - agent: Agent to call
    ///   - voiceID: Voice ID for TTS (from AgentVoiceConfigStorage)
    ///   - rootEvent: Optional thread to continue (if opening from existing conversation)
    ///   - branchTag: Optional branch tag for voice mode
    ///   - userPubkey: Current user's pubkey (for filtering messages)
    ///   - enableVOD: Whether to record the call for playback (Video/Voice on Demand)
    ///   - autoTTS: Whether to automatically speak agent responses
    ///   - vadController: Optional VAD controller for hands-free operation
    ///   - vadMode: Voice activity detection mode
    ///   - onSendMessage: Callback to send message to agent (messageText, agentPubkey, tags in Nostr format)
    ///                    Returns the thread event ID if a new thread was created (for subscription setup)
    public init(
        audioService: AudioService,
        ndk: NDK,
        projectID: String,
        agent: ProjectAgent,
        userPubkey: String,
        onSendMessage: @escaping (String, String, [[String]]) async throws -> String?,
        voiceID: String? = nil,
        rootEvent: NDKEvent? = nil,
        branchTag: String? = nil,
        enableVOD: Bool = true,
        autoTTS: Bool = true,
        vadController: VADController? = nil,
        vadMode: VADMode = .pushToTalk
    ) {
        self.audioService = audioService
        self.ndk = ndk
        self.projectID = projectID
        self.agent = agent
        self.voiceID = voiceID
        self.currentThreadID = rootEvent?.id
        self.branchTag = branchTag
        self.userPubkey = userPubkey
        self.enableVOD = enableVOD
        self.autoTTS = autoTTS
        self.vadController = vadController
        self.vadMode = vadMode
        self.onSendMessage = onSendMessage
    }

    // MARK: Public

    /// Current call state
    public private(set) var state: CallState = .idle

    /// Current transcript from STT
    public private(set) var currentTranscript = ""

    /// Conversation state (manages messages and subscriptions)
    public private(set) var conversationState: ConversationState?

    /// Error message if any
    public private(set) var error: String?

    /// Agent in the call (mutable to allow changing during call)
    public private(set) var agent: ProjectAgent

    /// Voice ID for TTS (from AgentVoiceConfigStorage)
    public let voiceID: String?

    /// Whether mic is muted (VAD won't trigger)
    public private(set) var isMuted = false

    /// Current thread ID for subscriptions
    public private(set) var currentThreadID: String?

    /// Whether VOD recording is enabled
    public let enableVOD: Bool

    /// Whether auto-TTS is enabled
    public private(set) var autoTTS: Bool

    /// Call duration
    public private(set) var callDuration: TimeInterval = 0.0

    /// VOD recording URL (if recording is enabled)
    public private(set) var vodRecordingURL: URL?

    /// VAD mode
    public private(set) var vadMode: VADMode

    /// Whether user is holding the mic (tap-to-hold)
    public private(set) var isHoldingMic = false

    /// Whether TTS playback is paused
    public private(set) var isPaused = false

    /// Whether agent is processing (21111 streaming event received)
    public private(set) var agentIsProcessing = false

    /// Current user's public key (for filtering messages)
    public let userPubkey: String

    /// Audio level for visualization (0.0 to 1.0)
    public var audioLevel: Double {
        self.audioService.recorder.audioLevel
    }

    /// Whether the call is active
    public var isCallActive: Bool {
        self.state != .idle && self.state != .ended
    }

    /// Whether user can record (not muted and in listening state)
    public var canRecord: Bool {
        !self.isMuted && self.state == .listening
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
            self.logger.info("[startCall] Already started, state=\(String(describing: self.state))")
            return
        }

        self.logger.info("[startCall] Starting call...")
        self.error = nil
        self.state = .connecting
        self.callStartTime = Date()

        // Start VOD recording if enabled
        if self.enableVOD {
            self.logger.info("[startCall] Starting VOD recording")
            await self.startVODRecording()
        }

        // Start VAD if enabled
        self.logger.info("[startCall] VAD mode: \(String(describing: self.vadMode))")
        if self.vadMode == .auto || self.vadMode == .autoWithHold {
            self.logger.info("[startCall] Starting VAD")
            await self.startVAD()
        } else {
            self.logger.info("[startCall] VAD not started (push-to-talk mode)")
        }

        // Initialize TTS Queue
        if self.autoTTS {
            self.ttsQueue = TTSQueue(
                audioService: self.audioService,
                userPubkey: self.userPubkey,
                voiceID: self.voiceID
            )

            self.ttsQueue?.onPlaybackStateChange = { [weak self] isPlaying in
                guard let self else {
                    return
                }
                if isPlaying {
                    // TTS started - no longer in "processing" state
                    self.agentIsProcessing = false
                    self.state = .playingResponse
                } else if self.state == .playingResponse {
                    self.state = .listening
                }
            }
        }

        // Subscribe to conversation if thread ID exists
        if let threadID = self.currentThreadID {
            self.conversationState = ConversationState(rootEventID: threadID)
            Task {
                await self.subscribeToConversation()
            }
        }

        // Transition to listening state
        self.state = .listening
        self.logger.info("[startCall] Call started, state=.listening, canRecord=\(self.canRecord)")
    }

    /// End the call
    public func endCall() async {
        // Cancel any recording
        if self.state == .recording {
            await self.audioService.cancelRecording()
        }

        // Stop VAD
        await self.stopVAD()

        // Cancel any ongoing TTS task
        self.ttsTask?.cancel()
        self.ttsTask = nil

        // Stop any playback
        self.audioService.stopSpeaking()

        // Clear TTS queue and subscriptions
        self.ttsQueue?.clearQueue()
        self.subscriptionTask?.cancel()
        self.subscriptionTask = nil
        self.subscription = nil
        self.streamingSubscriptionTask?.cancel()
        self.streamingSubscriptionTask = nil
        self.streamingSubscription = nil
        self.conversationState = nil

        // Stop VOD recording
        await self.stopVODRecording()

        // Update state
        self.state = .ended
        self.currentTranscript = ""
        self.isHoldingMic = false
        self.isPaused = false
        self.agentIsProcessing = false

        // Calculate final duration
        if let startTime = callStartTime {
            self.callDuration = Date().timeIntervalSince(startTime)
        }
    }

    // MARK: - Voice Input

    /// Start recording user speech
    public func startRecording() async {
        guard self.canRecord else {
            self.logger.warning("[startRecording] Cannot record - canRecord is false")
            return
        }

        self.logger.info("[startRecording] Starting recording...")
        self.error = nil
        self.state = .recording

        do {
            try await self.audioService.startRecording()
            self.logger.info("[startRecording] Recording started successfully")
        } catch {
            self.logger.error("[startRecording] Failed: \(error.localizedDescription)")
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
        self.logger
            .info("[toggleRecording] Called. state=\(String(describing: self.state)), canRecord=\(self.canRecord)")
        if self.state == .recording {
            self.logger.info("[toggleRecording] Stopping recording")
            await self.stopRecording()
        } else if self.canRecord {
            self.logger.info("[toggleRecording] Starting recording")
            await self.startRecording()
        } else {
            self.logger.warning("[toggleRecording] Cannot record - state is not .listening")
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

        self.state = .waitingForAgent

        do {
            // Build tags with voice mode and branch (if specified)
            var tags: [[String]] = [["mode", "voice"]]
            if let branchTag = self.branchTag {
                tags.append(["branch", branchTag])
            }

            // Send message via callback - may return thread ID if new thread was created
            let returnedThreadID = try await self.onSendMessage(messageText, self.agent.pubkey, tags)

            // If we got a new thread ID and don't have one yet, set up subscription
            if let newThreadID = returnedThreadID, self.currentThreadID == nil {
                self.currentThreadID = newThreadID
                self.conversationState = ConversationState(rootEventID: newThreadID)
                await self.subscribeToConversation()
            }

            // Return to listening state (agent response will come via subscription)
            self.state = .listening
        } catch {
            self.error = error.localizedDescription
            // Restore transcript on failure
            self.currentTranscript = messageText
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

    /// Interrupt agent speech (called from UI long-press)
    public func interruptAgent() {
        guard self.state == .playingResponse || self.isPaused || self.agentIsProcessing else {
            return
        }
        self.ttsQueue?.clearQueue()
        self.audioService.stopSpeaking()
        self.isPaused = false
        self.agentIsProcessing = false
        self.state = .listening
    }

    /// Toggle pause state (pauses entire TTS queue)
    public func togglePause() {
        guard self.state == .playingResponse || self.isPaused else {
            return
        }

        if self.isPaused {
            // Resume
            self.isPaused = false
            self.audioService.player.resume()
        } else {
            // Pause
            self.isPaused = true
            self.audioService.player.pause()
        }
    }

    /// Replay a specific message's audio
    public func replayMessage(_ messageID: String) async {
        guard let conversationState = self.conversationState else {
            return
        }

        guard let message = conversationState.displayMessages.first(where: { $0.id == messageID }) else {
            return
        }

        let previousState = self.state
        self.state = .playingResponse

        do {
            // Check cache first
            if let cachedAudio = TTSCache.shared.audioFor(messageID: messageID) {
                try await self.audioService.play(audioData: cachedAudio)
            } else {
                // Not cached - synthesize (which will cache for future)
                try await self.audioService.speak(text: message.content, voiceID: self.voiceID)
            }
            self.state = previousState
        } catch {
            self.error = error.localizedDescription
            self.state = previousState
        }
    }

    // MARK: - Tap-to-Hold

    /// Start holding the mic (disables VAD auto-stop)
    public func startHoldingMic() async {
        guard self.vadMode == .autoWithHold, !self.isHoldingMic else {
            return
        }

        self.isHoldingMic = true
        self.vadController?.pause()

        // Start recording if not already recording
        if self.canRecord {
            await self.startRecording()
        }
    }

    /// Stop holding the mic (re-enables VAD auto-stop)
    public func stopHoldingMic() async {
        guard self.isHoldingMic else {
            return
        }

        self.isHoldingMic = false
        self.vadController?.resume()

        // Stop recording if currently recording
        if self.state == .recording {
            await self.stopRecording()
        }
    }

    // MARK: - Mute Control

    /// Toggle microphone mute state
    /// When muted, VAD won't trigger and manual recording is disabled
    public func toggleMute() {
        self.isMuted.toggle()
        self.logger.info("[toggleMute] isMuted=\(self.isMuted)")
    }

    // MARK: - Agent Selection

    /// Change the current agent
    /// - Parameter newAgent: The new agent to speak with
    public func changeAgent(_ newAgent: ProjectAgent) {
        self.agent = newAgent
        self.logger.info("[changeAgent] Changed to agent: \(newAgent.name)")
    }

    // MARK: Private

    // MARK: - Constants

    private static let vodRetentionDays = 30

    private let audioService: AudioService
    private let ndk: NDK
    private let projectID: String
    private let branchTag: String?
    private let onSendMessage: (String, String, [[String]]) async throws -> String?
    private var callStartTime: Date?
    private let logger = Logger(subsystem: "com.tenex.ios", category: "CallViewModel")
    private let vodActor = VODRecordingActor()
    private var ttsTask: Task<Void, Never>?
    private let vadController: VADController?

    // TTS Queue and subscriptions
    private var ttsQueue: TTSQueue?
    private var subscription: NDKSubscription<NDKEvent>?
    private var subscriptionTask: Task<Void, Never>?
    private var streamingSubscription: NDKSubscription<NDKEvent>?
    private var streamingSubscriptionTask: Task<Void, Never>?

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
    private func recordMessageToVOD(message: Message, to url: URL) async {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return
        }

        do {
            // Create message entry
            let messageEntry: [String: Any] = [
                "id": message.id,
                "sender": message.pubkey == self.userPubkey ? "user" : "agent",
                "content": message.content,
                "timestamp": ISO8601DateFormatter().string(from: message.createdAt),
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

    // MARK: - VAD Integration

    /// Start VAD and set up callbacks
    private func startVAD() async {
        guard let vadController else {
            return
        }

        // Set up VAD callbacks
        vadController.onSpeechStart = { [weak self] in
            Task { @MainActor [weak self] in
                await self?.handleVADSpeechStart()
            }
        }

        vadController.onSpeechEnd = { [weak self] in
            Task { @MainActor [weak self] in
                await self?.handleVADSpeechEnd()
            }
        }

        // Start VAD
        do {
            try await vadController.start()
        } catch {
            self.logger.error("Failed to start VAD: \(error.localizedDescription)")
            self.error = "VAD failed to start: \(error.localizedDescription)"
        }
    }

    /// Stop VAD
    private func stopVAD() async {
        await self.vadController?.stop()
    }

    /// Handle VAD speech start event
    private func handleVADSpeechStart() async {
        // Don't interrupt when agent is speaking - user must tap to interrupt
        // This prevents echo (microphone picking up speaker output)
        guard self.state != .playingResponse, !self.isPaused else {
            return
        }

        // Don't start recording if muted or holding
        guard !self.isMuted, !self.isHoldingMic else {
            return
        }

        await self.startRecording()
    }

    /// Handle VAD speech end event
    private func handleVADSpeechEnd() async {
        guard !self.isHoldingMic else {
            return
        }

        await self.stopRecording()

        // Auto-send after VAD transcription (like a real phone call)
        if self.canSend {
            self.logger.info("[handleVADSpeechEnd] Auto-sending after VAD transcription")
            await self.sendMessage()
        }
    }

    // MARK: - Conversation Subscription

    /// Subscribe to conversation events and process incoming messages
    private func subscribeToConversation() async {
        guard let threadID = self.currentThreadID else {
            self.logger.warning("[subscribeToConversation] No thread ID, cannot subscribe")
            return
        }

        self.logger.info("[subscribeToConversation] Subscribing to thread: \(threadID)")

        // Subscribe to kind 1111 final messages
        let filter = NDKFilter(
            kinds: [1111],
            tags: ["E": Set([threadID])]
        )

        self.subscription = self.ndk.subscribe(filter: filter)

        // Subscribe to kind 21111 streaming events (agent processing indicator)
        let streamingFilter = NDKFilter(
            kinds: [21_111],
            since: Timestamp(Date().addingTimeInterval(-60).timeIntervalSince1970),
            tags: ["E": Set([threadID])]
        )

        self.streamingSubscription = self.ndk.subscribe(filter: streamingFilter)

        // Process streaming events (21111) - show processing indicator
        if let streamingSub = self.streamingSubscription {
            self.streamingSubscriptionTask = Task {
                for await event in streamingSub.events {
                    guard !Task.isCancelled else {
                        return
                    }
                    // Agent started generating response
                    if event.pubkey != self.userPubkey {
                        self.agentIsProcessing = true
                        self.logger.info("[subscribeToConversation] Agent is processing (21111 received)")
                    }
                }
            }
        }

        // Process final message events (1111)
        guard let subscription = self.subscription else {
            return
        }

        self.subscriptionTask = Task {
            for await event in subscription.events {
                guard !Task.isCancelled else {
                    return
                }

                guard let message = Message.from(event: event) else {
                    continue
                }

                // Process event in ConversationState
                self.conversationState?.processEvent(event)

                // Queue for TTS if from agent and autoTTS is enabled
                if message.pubkey != self.userPubkey, self.autoTTS {
                    self.ttsQueue?.processMessages([message])
                }
            }
        }
    }
}

// swiftlint:enable type_body_length file_length
