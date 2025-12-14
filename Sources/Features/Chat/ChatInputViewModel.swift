//
// ChatInputViewModel.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation
import Observation

// MARK: - ChatInputViewModel

/// View model for chat input field
/// Tracks input text, selected agent, and mentioned pubkeys for p-tags
@MainActor
@Observable
public final class ChatInputViewModel {
    // MARK: Lifecycle

    /// Initialize the chat input view model
    /// - Parameter audioService: Optional audio service for voice input
    public init(audioService: AudioService? = nil) {
        self.audioService = audioService
    }

    // MARK: Public

    /// The currently selected agent pubkey
    public private(set) var selectedAgent: String?

    /// The currently selected branch ID
    public private(set) var selectedBranch: String?

    /// Pubkeys mentioned in the message (for p-tags)
    public private(set) var mentionedPubkeys: [String] = []

    /// Whether the send button should be enabled
    public private(set) var canSend = false

    /// Whether voice input is currently recording
    public private(set) var isRecording = false

    /// Error from audio operations
    public private(set) var audioError: String?

    /// Current audio level (0.0 to 1.0) during recording
    public var audioLevel: Double {
        audioService?.recorder.audioLevel ?? 0.0
    }

    /// Whether audio service is available for voice input
    public var isVoiceInputAvailable: Bool {
        audioService != nil
    }

    /// The current input text
    public var inputText = "" {
        didSet {
            updateCanSend()
        }
    }

    /// Select an agent
    /// - Parameter pubkey: The agent's pubkey
    public func selectAgent(_ pubkey: String) {
        selectedAgent = pubkey
    }

    /// Select a branch
    /// - Parameter branchId: The branch identifier
    public func selectBranch(_ branchID: String) {
        selectedBranch = branchID
    }

    /// Insert a mention replacement into the text
    /// - Parameters:
    ///   - replacement: The text to insert (agent name)
    ///   - pubkey: The agent's pubkey to track for p-tag
    public func insertMention(replacement: String, pubkey: String) {
        // Find the @trigger position and replace with the agent name
        // The MentionAutocompleteViewModel has already calculated the replacement
        // which includes finding and removing the @trigger prefix

        // Track the mentioned pubkey for p-tag generation
        if !mentionedPubkeys.contains(pubkey) {
            mentionedPubkeys.append(pubkey)
        }

        // Replace the last @... with the agent name
        if let atRange = inputText.range(of: "@", options: .backwards) {
            inputText = String(inputText[..<atRange.lowerBound]) + replacement + " "
        }
    }

    /// Clear the input text and mentions
    public func clearInput() {
        inputText = ""
        mentionedPubkeys = []
    }

    /// Toggle voice recording on/off
    public func toggleVoiceInput() async {
        guard let audioService else {
            audioError = "Voice input not available"
            return
        }

        audioError = nil

        if isRecording {
            // Stop recording and transcribe
            do {
                let transcript = try await audioService.stopRecording()
                if !transcript.isEmpty {
                    // Append transcript to input text
                    if inputText.isEmpty {
                        inputText = transcript
                    } else {
                        inputText += " " + transcript
                    }
                }
                isRecording = false
            } catch {
                audioError = error.localizedDescription
                isRecording = false
            }
        } else {
            // Start recording
            do {
                try await audioService.startRecording()
                isRecording = true
            } catch {
                audioError = error.localizedDescription
                isRecording = false
            }
        }
    }

    /// Cancel voice recording without transcribing
    public func cancelVoiceInput() async {
        guard let audioService, isRecording else {
            return
        }

        await audioService.cancelRecording()
        isRecording = false
    }

    // MARK: Private

    private let audioService: AudioService?

    private func updateCanSend() {
        canSend = !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
