//
// AISettingsViewModel.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation
import Observation
import TENEXCore

// MARK: - AISettingsViewModel

/// View model for AI settings management
@MainActor
@Observable
public final class AISettingsViewModel {
    // MARK: Lifecycle

    /// Initialize with dependencies
    /// - Parameters:
    ///   - storage: AI configuration storage
    ///   - capabilityDetector: Device capability detector
    public init(
        storage: AIConfigStorage,
        capabilityDetector: AICapabilityDetector = RuntimeAICapabilityDetector()
    ) {
        self.storage = storage
        self.capabilityDetector = capabilityDetector
        config = AIConfig()
    }

    // MARK: Public

    /// Current AI configuration
    public var config: AIConfig

    /// Whether a save operation is in progress
    public var isSaving = false

    /// Error message from save operation
    public var saveError: String?

    /// Whether a load operation is in progress
    public var isLoading = false

    /// Error message from load operation
    public var loadError: String?

    /// Whether there are unsaved changes
    public var hasUnsavedChanges: Bool {
        guard let original = originalConfig else {
            return false
        }
        return config != original
    }

    /// Available LLM providers (filtered by device capability)
    public var availableLLMProviders: [LLMProvider] {
        LLMProvider.allCases.filter { provider in
            switch provider {
            case .appleIntelligence:
                capabilityDetector.isAppleIntelligenceAvailable()
            default:
                true
            }
        }
    }

    /// Available STT providers (filtered by device capability)
    public var availableSTTProviders: [STTProvider] {
        STTProvider.allCases.filter { provider in
            switch provider {
            case .speechTranscriber:
                capabilityDetector.isSpeechTranscriberAvailable()
            case .whisperKit:
                capabilityDetector.isWhisperKitAvailable()
            default:
                true
            }
        }
    }

    /// All TTS providers are always available
    public var availableTTSProviders: [TTSProvider] {
        TTSProvider.allCases
    }

    /// Load configuration from storage
    public func load() async {
        isLoading = true
        loadError = nil

        do {
            if let loaded = try storage.load() {
                config = loaded
                originalConfig = loaded
            } else {
                // No saved config, use default
                config = AIConfig()
                originalConfig = nil
            }
        } catch {
            loadError = "Failed to load configuration: \(error.localizedDescription)"
        }

        isLoading = false
    }

    /// Save current configuration
    public func save() async throws {
        isSaving = true
        saveError = nil

        do {
            try storage.save(config)
            originalConfig = config
        } catch {
            saveError = "Failed to save configuration: \(error.localizedDescription)"
            throw error
        }

        isSaving = false
    }

    /// Add a new LLM configuration
    /// - Parameters:
    ///   - llmConfig: The LLM configuration to add
    ///   - apiKey: The API key for this configuration
    public func addLLMConfig(_ llmConfig: LLMConfig, apiKey: String) async throws {
        // Save API key to keychain
        try storage.saveAPIKey(apiKey, for: llmConfig.id)

        // Add config to list
        config.llmConfigs.append(llmConfig)

        // If this is the first config, make it active
        if config.activeLLMConfigID == nil {
            config.activeLLMConfigID = llmConfig.id
        }
    }

    /// Update an existing LLM configuration
    /// - Parameters:
    ///   - llmConfig: The updated LLM configuration
    ///   - apiKey: The new API key (if changed)
    public func updateLLMConfig(_ llmConfig: LLMConfig, apiKey: String?) async throws {
        guard let index = config.llmConfigs.firstIndex(where: { $0.id == llmConfig.id }) else {
            throw AISettingsError.configNotFound
        }

        // Update API key if provided
        if let newKey = apiKey {
            try storage.saveAPIKey(newKey, for: llmConfig.id)
        }

        // Update config
        config.llmConfigs[index] = llmConfig
    }

    /// Remove an LLM configuration
    /// - Parameter id: The ID of the configuration to remove
    public func removeLLMConfig(id: String) async throws {
        // Remove from list
        config.llmConfigs.removeAll { $0.id == id }

        // Delete API key
        try storage.deleteAPIKey(for: id)

        // If this was the active config, clear active ID
        if config.activeLLMConfigID == id {
            config.activeLLMConfigID = config.llmConfigs.first?.id
        }

        // Remove from feature assignments
        for feature in AIFeature.allCases where config.featureAssignments[feature] == id {
            config.featureAssignments[feature] = nil
        }
    }

    /// Set the active LLM configuration
    /// - Parameter id: The ID of the configuration to activate
    public func setActiveLLMConfig(id: String) async throws {
        guard config.llmConfigs.contains(where: { $0.id == id }) else {
            throw AISettingsError.configNotFound
        }
        config.activeLLMConfigID = id
    }

    /// Set feature assignment
    /// - Parameters:
    ///   - feature: The AI feature
    ///   - configID: The configuration ID to assign (nil to use active config)
    public func setFeatureAssignment(feature: AIFeature, configID: String?) async throws {
        if let id = configID {
            guard config.llmConfigs.contains(where: { $0.id == id }) else {
                throw AISettingsError.configNotFound
            }
        }
        config.featureAssignments[feature] = configID
    }

    /// Get API key for a configuration
    /// - Parameter configID: The configuration ID
    /// - Returns: The API key, or nil if not found
    public func getAPIKey(for configID: String) throws -> String? {
        try storage.loadAPIKey(for: configID)
    }

    // MARK: Private

    private let storage: AIConfigStorage
    private let capabilityDetector: AICapabilityDetector
    private var originalConfig: AIConfig?
}

// MARK: - AISettingsError

/// Errors that can occur in AI settings
public enum AISettingsError: Error, LocalizedError {
    case configNotFound

    // MARK: Public

    public var errorDescription: String? {
        switch self {
        case .configNotFound:
            "Configuration not found"
        }
    }
}
