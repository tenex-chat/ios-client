//
// VODRecordingActor.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation

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
