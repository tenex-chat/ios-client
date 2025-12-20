//
// TTSQueue.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation
import Observation
import OSLog
import TENEXCore

// MARK: - TTSQueue

/// Manages sequential TTS playback with initialization tracking to prevent replaying historical messages
@MainActor
@Observable
public final class TTSQueue {
    // MARK: Lifecycle

    // MARK: - Initialization

    /// Initialize TTS queue
    /// - Parameters:
    ///   - audioService: Audio service for TTS playback
    ///   - userPubkey: Current user's public key to filter out user messages
    ///   - voiceID: Optional voice ID for TTS (deprecated, use availableVoices and agentVoiceStorage)
    ///   - availableVoices: Available configured voices from TTS settings
    ///   - agentVoiceStorage: Storage for agent-specific voice configurations
    public init(
        audioService: AudioService,
        userPubkey: String,
        voiceID: String? = nil,
        availableVoices: [VoiceConfig] = [],
        agentVoiceStorage: AgentVoiceConfigStorage? = nil
    ) {
        self.audioService = audioService
        self.userPubkey = userPubkey
        self.voiceID = voiceID
        self.availableVoices = availableVoices
        self.agentVoiceStorage = agentVoiceStorage ?? AgentVoiceConfigStorage()
    }

    // MARK: Public

    // MARK: - State

    /// Whether the queue is currently processing a message
    public private(set) var isProcessing = false

    // MARK: - Callbacks

    /// Called when playback state changes (playing/stopped)
    public var onPlaybackStateChange: ((Bool) -> Void)?

    // MARK: - Public Methods

    /// Process incoming messages and queue them for TTS playback
    /// - Parameter messages: Array of messages to process
    public func processMessages(_ messages: [Message]) {
        // On first call, mark all messages as "played" (historical)
        // to prevent replaying conversation history
        if !self.isInitialized {
            for message in messages {
                self.playedMessageIDs.insert(message.id)
            }
            self.isInitialized = true
            return
        }

        // After initialization, only queue new messages from agents
        for message in messages {
            // Skip if already played
            guard !self.playedMessageIDs.contains(message.id) else {
                continue
            }

            // Skip user's own messages
            guard message.pubkey != self.userPubkey else {
                self.playedMessageIDs.insert(message.id)
                continue
            }

            // Skip reasoning messages (don't speak thinking content)
            guard !message.isReasoning else {
                self.playedMessageIDs.insert(message.id)
                continue
            }

            // Queue for TTS (voiceID will be determined per-agent when processing)
            self.addToQueue(TTSMessage(
                id: message.id,
                content: message.content,
                voiceID: nil,
                agentPubkey: message.pubkey
            ))

            // Mark as played to prevent duplicate queueing
            self.playedMessageIDs.insert(message.id)
        }

        // Start processing if not already processing
        if !self.isProcessing, !self.queue.isEmpty {
            self.isProcessing = true
            Task {
                await self.processNextInQueue()
            }
        }
    }

    /// Clear the queue and stop current playback (called on VAD interruption)
    public func clearQueue() {
        self.queue.removeAll()
        self.audioService.stopSpeaking()

        if self.isProcessing {
            self.isProcessing = false
            self.onPlaybackStateChange?(false)
        }
    }

    // MARK: Private

    /// Whether the queue has been initialized (prevents playing historical messages)
    private var isInitialized = false

    // MARK: - Queue Management

    /// Queue of pending TTS messages
    private var queue: [TTSMessage] = []

    /// Set of message IDs that have been played or marked as historical
    private var playedMessageIDs: Set<String> = []

    // MARK: - Dependencies

    private let audioService: AudioService
    private let userPubkey: String
    private let voiceID: String?
    private let availableVoices: [VoiceConfig]
    private let agentVoiceStorage: AgentVoiceConfigStorage
    private let logger = Logger(subsystem: "com.tenex.ios", category: "TTSQueue")

    // MARK: - Private Methods

    /// Add a message to the queue
    private func addToQueue(_ message: TTSMessage) {
        self.queue.append(message)
    }

    /// Process the next message in the queue
    private func processNextInQueue() async {
        guard !self.queue.isEmpty else {
            if self.isProcessing {
                self.isProcessing = false
                self.onPlaybackStateChange?(false)
            }
            return
        }

        let message = self.queue.removeFirst()

        self.isProcessing = true
        self.onPlaybackStateChange?(true)

        do {
            // Determine the voice to use for this specific message
            let voiceToUse = VoiceSelectionHelper.selectVoice(
                for: message.agentPubkey,
                availableVoices: self.availableVoices,
                agentVoiceStorage: self.agentVoiceStorage
            ) ?? message.voiceID ?? self.voiceID

            self.logger.info("Playing message \(message.id) from agent \(message.agentPubkey) with voice: \(voiceToUse ?? "default")")

            // Check cache first
            if let cachedAudio = TTSCache.shared.audioFor(messageID: message.id) {
                self.logger.info("Playing cached audio for message: \(message.id)")
                try await self.audioService.play(audioData: cachedAudio)
            } else {
                // Synthesize, cache, then play
                let audioData = try await self.audioService.synthesize(
                    text: message.content,
                    voiceID: voiceToUse
                )

                // Cache the audio
                TTSCache.shared.save(
                    audioData: audioData,
                    messageID: message.id,
                    text: message.content,
                    voiceID: voiceToUse ?? "",
                    agentPubkey: message.agentPubkey
                )

                // Play the audio
                try await self.audioService.play(audioData: audioData)
            }
        } catch {
            self.logger.error("Failed to play message \(message.id): \(error.localizedDescription)")
        }

        // Process next message
        await self.processNextInQueue()
    }
}

// MARK: - TTSMessage

/// A message queued for TTS playback
struct TTSMessage {
    let id: String
    let content: String
    let voiceID: String?
    let agentPubkey: String
}
