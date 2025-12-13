//
// AIConfig.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation

// MARK: - LLMProvider

/// LLM provider types
public enum LLMProvider: String, Codable, CaseIterable, Sendable {
    case openai
    case anthropic
    case google
    case openrouter
    case ollama
    case appleIntelligence = "apple-intelligence"
}

// MARK: - TTSProvider

/// Text-to-speech provider types
public enum TTSProvider: String, Codable, CaseIterable, Sendable {
    case openai
    case elevenlabs
    case system
}

// MARK: - STTProvider

/// Speech-to-text provider types
public enum STTProvider: String, Codable, CaseIterable, Sendable {
    case whisper
    case elevenlabs
    case speechTranscriber = "speech-transcriber" // iOS 18+ SpeechAnalyzer/SpeechTranscriber
    case whisperKit = "whisper-kit"
}

// MARK: - AIFeature

/// AI feature types that can be assigned to specific configurations
public enum AIFeature: String, Codable, CaseIterable, Sendable {
    case titleGeneration = "title-generation"
    case summarization
    case systemPrompt = "system-prompt"
}

// MARK: - LLMConfig

/// Configuration for a language model provider
public struct LLMConfig: Identifiable, Codable, Sendable, Equatable {
    // MARK: Lifecycle

    public init(
        name: String,
        provider: LLMProvider,
        model: String,
        baseURL: String? = nil,
        id: String = UUID().uuidString
    ) {
        self.id = id
        self.name = name
        self.provider = provider
        self.model = model
        self.baseURL = baseURL
    }

    // MARK: Public

    /// Unique identifier
    public let id: String
    /// User-defined name for this configuration (e.g., "Fast", "Quality", "Local")
    public var name: String
    /// The LLM provider type
    public var provider: LLMProvider
    /// Model identifier (e.g., "gpt-4o", "claude-3-5-sonnet-20241022")
    public var model: String
    /// Optional base URL for custom or Ollama providers
    public var baseURL: String?
}

// MARK: - VoiceMetadata

/// Metadata for a voice
public struct VoiceMetadata: Codable, Sendable, Equatable {
    // MARK: Lifecycle

    public init(gender: String? = nil, accent: String? = nil, ageRange: String? = nil) {
        self.gender = gender
        self.accent = accent
        self.ageRange = ageRange
    }

    // MARK: Public

    /// Voice gender (e.g., "Male", "Female", "Neutral")
    public var gender: String?
    /// Voice accent (e.g., "American", "British", "Australian")
    public var accent: String?
    /// Age range (e.g., "Young", "Middle-aged", "Old")
    public var ageRange: String?
}

// MARK: - VoiceConfig

/// Configuration for a text-to-speech voice
public struct VoiceConfig: Identifiable, Codable, Sendable, Equatable {
    // MARK: Lifecycle

    public init(
        name: String,
        provider: TTSProvider,
        voiceID: String,
        metadata: VoiceMetadata? = nil,
        id: String = UUID().uuidString
    ) {
        self.id = id
        self.name = name
        self.provider = provider
        self.voiceID = voiceID
        self.metadata = metadata
    }

    // MARK: Public

    /// Unique identifier
    public let id: String
    /// User-defined name for this voice
    public var name: String
    /// The TTS provider
    public var provider: TTSProvider
    /// Voice identifier from the provider
    public var voiceID: String
    /// Optional metadata about the voice
    public var metadata: VoiceMetadata?
}

// MARK: - TTSSettings

/// Text-to-speech settings
public struct TTSSettings: Codable, Sendable, Equatable {
    // MARK: Lifecycle

    public init(
        enabled: Bool = false,
        voiceConfigs: [VoiceConfig] = [],
        speed: Double = 1.0,
        autoSpeak: Bool = false
    ) {
        self.enabled = enabled
        self.voiceConfigs = voiceConfigs
        self.speed = speed
        self.autoSpeak = autoSpeak
    }

    // MARK: Public

    /// Whether TTS is enabled
    public var enabled: Bool
    /// Configured voices (up to 10)
    public var voiceConfigs: [VoiceConfig]
    /// Speech speed (0.5 - 2.0)
    public var speed: Double
    /// Whether to automatically speak agent responses
    public var autoSpeak: Bool
}

// MARK: - STTSettings

/// Speech-to-text settings
public struct STTSettings: Codable, Sendable, Equatable {
    // MARK: Lifecycle

    public init(
        enabled: Bool = false,
        provider: STTProvider = .whisper,
        model: String = "whisper-1",
        fallbackChain: [STTProvider] = []
    ) {
        self.enabled = enabled
        self.provider = provider
        self.model = model
        self.fallbackChain = fallbackChain
    }

    // MARK: Public

    /// Whether STT is enabled
    public var enabled: Bool
    /// Primary STT provider
    public var provider: STTProvider
    /// Model identifier (e.g., "whisper-1")
    public var model: String
    /// Fallback providers in order of preference
    public var fallbackChain: [STTProvider]
}

// MARK: - AIConfig

/// Main container for all AI configuration
public struct AIConfig: Codable, Sendable, Equatable {
    // MARK: Lifecycle

    public init(
        llmConfigs: [LLMConfig] = [],
        activeLLMConfigID: String? = nil,
        featureAssignments: [AIFeature: String] = [:],
        ttsSettings: TTSSettings = TTSSettings(),
        sttSettings: STTSettings = STTSettings()
    ) {
        self.llmConfigs = llmConfigs
        self.activeLLMConfigID = activeLLMConfigID
        self.featureAssignments = featureAssignments
        self.ttsSettings = ttsSettings
        self.sttSettings = sttSettings
    }

    // MARK: Public

    /// List of configured LLM providers
    public var llmConfigs: [LLMConfig]
    /// ID of the active LLM configuration
    public var activeLLMConfigID: String?
    /// Feature-specific LLM assignments (overrides active config)
    public var featureAssignments: [AIFeature: String]
    /// Text-to-speech settings
    public var ttsSettings: TTSSettings
    /// Speech-to-text settings
    public var sttSettings: STTSettings
}
