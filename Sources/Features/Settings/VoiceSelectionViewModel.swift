//
// VoiceSelectionViewModel.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation
import Observation
import TENEXCore

// MARK: - VoiceOption

/// Represents a voice option for selection
public struct VoiceOption: Identifiable, Sendable {
    // MARK: Lifecycle

    public init(
        id: String,
        name: String,
        provider: TTSProvider,
        voiceID: String,
        metadata: VoiceMetadata? = nil
    ) {
        self.id = id
        self.name = name
        self.provider = provider
        self.voiceID = voiceID
        self.metadata = metadata
    }

    // MARK: Public

    public let id: String
    public let name: String
    public let provider: TTSProvider
    public let voiceID: String
    public let metadata: VoiceMetadata?

    /// Display text for the voice
    public var displayText: String {
        var text = name
        if let gender = metadata?.gender {
            text += " • \(gender)"
        }
        if let accent = metadata?.accent {
            text += " • \(accent)"
        }
        return text
    }
}

// MARK: - VoiceSelectionViewModel

/// View model for voice selection
@MainActor
@Observable
public final class VoiceSelectionViewModel {
    // MARK: Lifecycle

    /// Initialize with current voice configurations
    /// - Parameter currentVoices: Currently selected voices
    public init(currentVoices: [VoiceConfig]) {
        selectedVoiceIDs = Set(currentVoices.map(\.id))
        allVoices = Self.createVoiceOptions()
    }

    // MARK: Public

    /// Set of selected voice IDs
    public var selectedVoiceIDs: Set<String>

    /// Search query for filtering voices
    public var searchQuery = ""

    /// Selected provider filter (nil = all providers)
    public var selectedProvider: TTSProvider?

    /// Maximum number of voices that can be selected
    public let maxVoices = 10

    /// Available voices after filtering
    public var availableVoices: [VoiceOption] {
        var voices = allVoices

        // Filter by provider if selected
        if let provider = selectedProvider {
            voices = voices.filter { $0.provider == provider }
        }

        // Filter by search query
        if !searchQuery.isEmpty {
            let query = searchQuery.lowercased()
            voices = voices.filter {
                $0.name.lowercased().contains(query) ||
                    $0.metadata?.gender?.lowercased().contains(query) == true ||
                    $0.metadata?.accent?.lowercased().contains(query) == true
            }
        }

        return voices
    }

    /// Number of selected voices
    public var selectedCount: Int {
        selectedVoiceIDs.count
    }

    /// Whether maximum voices are selected
    public var isAtMaximum: Bool {
        selectedCount >= maxVoices
    }

    /// Toggle voice selection
    /// - Parameter id: Voice ID to toggle
    public func toggleVoice(id: String) {
        if selectedVoiceIDs.contains(id) {
            selectedVoiceIDs.remove(id)
        } else if selectedCount < maxVoices {
            selectedVoiceIDs.insert(id)
        }
    }

    /// Check if a voice is selected
    /// - Parameter id: Voice ID to check
    /// - Returns: True if selected
    public func isSelected(_ id: String) -> Bool {
        selectedVoiceIDs.contains(id)
    }

    /// Create VoiceConfig array from selections
    /// - Returns: Array of VoiceConfig objects for selected voices
    public func createVoiceConfigs() -> [VoiceConfig] {
        allVoices
            .filter { selectedVoiceIDs.contains($0.id) }
            .map { option in
                VoiceConfig(
                    name: option.name,
                    provider: option.provider,
                    voiceID: option.voiceID,
                    metadata: option.metadata,
                    id: option.id
                )
            }
    }

    // MARK: Private

    private let allVoices: [VoiceOption]

    /// Create predefined voice options
    /// Note: In production, these would be fetched from provider APIs
    private static func createVoiceOptions() -> [VoiceOption] {
        openAIVoices() + elevenLabsVoices() + systemVoices()
    }

    /// OpenAI TTS voices
    private static func openAIVoices() -> [VoiceOption] {
        [
            VoiceOption(
                id: "openai-alloy",
                name: "Alloy",
                provider: .openai,
                voiceID: "alloy",
                metadata: VoiceMetadata(gender: "Neutral", accent: "American")
            ),
            VoiceOption(
                id: "openai-echo",
                name: "Echo",
                provider: .openai,
                voiceID: "echo",
                metadata: VoiceMetadata(gender: "Male", accent: "American")
            ),
            VoiceOption(
                id: "openai-fable",
                name: "Fable",
                provider: .openai,
                voiceID: "fable",
                metadata: VoiceMetadata(gender: "Neutral", accent: "British")
            ),
            VoiceOption(
                id: "openai-onyx",
                name: "Onyx",
                provider: .openai,
                voiceID: "onyx",
                metadata: VoiceMetadata(gender: "Male", accent: "American")
            ),
            VoiceOption(
                id: "openai-nova",
                name: "Nova",
                provider: .openai,
                voiceID: "nova",
                metadata: VoiceMetadata(gender: "Female", accent: "American")
            ),
            VoiceOption(
                id: "openai-shimmer",
                name: "Shimmer",
                provider: .openai,
                voiceID: "shimmer",
                metadata: VoiceMetadata(gender: "Female", accent: "American")
            ),
        ]
    }

    /// ElevenLabs voices (examples - in production would fetch from API)
    private static func elevenLabsVoices() -> [VoiceOption] {
        [
            VoiceOption(
                id: "elevenlabs-rachel",
                name: "Rachel",
                provider: .elevenlabs,
                voiceID: "21m00Tcm4TlvDq8ikWAM",
                metadata: VoiceMetadata(gender: "Female", accent: "American")
            ),
            VoiceOption(
                id: "elevenlabs-domi",
                name: "Domi",
                provider: .elevenlabs,
                voiceID: "AZnzlk1XvdvUeBnXmlld",
                metadata: VoiceMetadata(gender: "Female", accent: "American")
            ),
            VoiceOption(
                id: "elevenlabs-adam",
                name: "Adam",
                provider: .elevenlabs,
                voiceID: "pNInz6obpgDQGcFmaJgB",
                metadata: VoiceMetadata(gender: "Male", accent: "American")
            ),
            VoiceOption(
                id: "elevenlabs-antoni",
                name: "Antoni",
                provider: .elevenlabs,
                voiceID: "ErXwobaYiN019PkySvjV",
                metadata: VoiceMetadata(gender: "Male", accent: "American")
            ),
        ]
    }

    /// System voices (iOS AVSpeechSynthesizer)
    private static func systemVoices() -> [VoiceOption] {
        [
            VoiceOption(
                id: "system-samantha",
                name: "Samantha",
                provider: .system,
                voiceID: "com.apple.ttsbundle.Samantha-compact",
                metadata: VoiceMetadata(gender: "Female", accent: "American")
            ),
            VoiceOption(
                id: "system-alex",
                name: "Alex",
                provider: .system,
                voiceID: "com.apple.ttsbundle.Alex-compact",
                metadata: VoiceMetadata(gender: "Male", accent: "American")
            ),
            VoiceOption(
                id: "system-daniel",
                name: "Daniel",
                provider: .system,
                voiceID: "com.apple.ttsbundle.Daniel-compact",
                metadata: VoiceMetadata(gender: "Male", accent: "British")
            ),
            VoiceOption(
                id: "system-karen",
                name: "Karen",
                provider: .system,
                voiceID: "com.apple.ttsbundle.Karen-compact",
                metadata: VoiceMetadata(gender: "Female", accent: "Australian")
            ),
        ]
    }
}
