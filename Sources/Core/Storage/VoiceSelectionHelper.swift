//
// VoiceSelectionHelper.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import CryptoKit
import Foundation
import os.log

// MARK: - VoiceSelectionHelper

/// Helper for selecting voices deterministically based on agent pubkeys
public enum VoiceSelectionHelper {
    // MARK: Public

    /// Select a voice for an agent based on their pubkey
    /// - Parameters:
    ///   - agentPubkey: The agent's public key
    ///   - availableVoices: Available configured voices (from TTS settings)
    ///   - agentVoiceStorage: Storage for agent-specific voice configurations
    ///   - persistAutoSelection: If true, automatically persist the selected voice to storage (default: true)
    /// - Returns: The voiceID to use, or nil if no voices are available
    public static func selectVoice(
        for agentPubkey: String,
        availableVoices: [VoiceConfig],
        agentVoiceStorage: AgentVoiceConfigStorage,
        persistAutoSelection: Bool = true
    ) -> String? {
        // First, check if this agent has an explicit configuration
        if let config = agentVoiceStorage.config(for: agentPubkey) {
            // Validate that the configured voice still exists
            if availableVoices.contains(where: { $0.voiceID == config.voiceID }) {
                Self.logger.debug("Using saved voice '\(config.voiceID)' for agent \(agentPubkey.prefix(8))...")
                return config.voiceID
            } else {
                // Configured voice no longer available, remove the stale config
                Self.logger.warning(
                    "Saved voice '\(config.voiceID)' for agent \(agentPubkey.prefix(8))... no longer available, selecting new voice"
                )
                agentVoiceStorage.removeConfig(for: agentPubkey)
            }
        }

        // If no explicit configuration and no available voices, return nil
        guard !availableVoices.isEmpty else {
            Self.logger.debug("No voices available for agent \(agentPubkey.prefix(8))...")
            return nil
        }

        // Deterministically select a voice based on the agent's pubkey
        // Sort voices by ID to ensure consistent ordering regardless of array order
        let sortedVoices = availableVoices.sorted { $0.id < $1.id }
        let selectedVoice = Self.deterministicVoiceSelection(
            agentPubkey: agentPubkey,
            sortedVoices: sortedVoices
        )

        Self.logger.info(
            "Auto-selected voice '\(selectedVoice.name)' (\(selectedVoice.voiceID)) for agent \(agentPubkey.prefix(8))..."
        )

        // Optionally persist the selection to prevent changes when voice list is modified
        if persistAutoSelection {
            let config = AgentVoiceConfig(voiceID: selectedVoice.voiceID)
            agentVoiceStorage.setConfig(config, for: agentPubkey)
            Self.logger.debug("Persisted auto-selected voice for agent \(agentPubkey.prefix(8))...")
        }

        return selectedVoice.voiceID
    }

    // MARK: Private

    private static let logger = Logger(
        subsystem: "com.tenex.TENEXiOSClient",
        category: "VoiceSelection"
    )

    /// Deterministically select a voice from sorted voices using agent pubkey hash
    /// - Parameters:
    ///   - agentPubkey: The agent's public key
    ///   - sortedVoices: Voices sorted by ID for consistent ordering
    /// - Returns: The selected VoiceConfig
    private static func deterministicVoiceSelection(
        agentPubkey: String,
        sortedVoices: [VoiceConfig]
    ) -> VoiceConfig {
        // Use SHA256 hash of the pubkey and modulo to pick from available voices
        let hash = SHA256.hash(data: Data(agentPubkey.utf8))

        // SHA256 produces 32 bytes, safely extract first 8 bytes as UInt64
        let hashValue = hash.withUnsafeBytes { (bytes: UnsafeRawBufferPointer) -> UInt64 in
            assert(bytes.count >= 8, "SHA256 should produce at least 8 bytes")
            return bytes.load(as: UInt64.self)
        }

        let index = Int(hashValue % UInt64(sortedVoices.count))
        return sortedVoices[index]
    }
}
