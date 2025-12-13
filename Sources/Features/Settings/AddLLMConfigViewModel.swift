//
// AddLLMConfigViewModel.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation
import Observation
import TENEXCore

// MARK: - AddLLMConfigViewModel

/// View model for adding/editing LLM configurations
@MainActor
@Observable
public final class AddLLMConfigViewModel {
    // MARK: Lifecycle

    /// Initialize for creating a new configuration
    /// - Parameter availableProviders: List of available providers
    public init(availableProviders: [LLMProvider]) {
        self.availableProviders = availableProviders
        name = ""
        provider = availableProviders.first ?? .openai
        model = ""
        apiKey = ""
        baseURL = ""
    }

    /// Initialize for editing an existing configuration
    /// - Parameters:
    ///   - config: Existing configuration to edit
    ///   - apiKey: Current API key
    ///   - availableProviders: List of available providers
    public init(
        config: LLMConfig,
        apiKey: String,
        availableProviders: [LLMProvider]
    ) {
        self.availableProviders = availableProviders
        name = config.name
        provider = config.provider
        model = config.model
        apiKey = apiKey
        baseURL = config.baseURL ?? ""
        configID = config.id
    }

    // MARK: Public

    /// User-defined name for this configuration
    public var name: String

    /// Selected provider
    public var provider: LLMProvider

    /// Model identifier
    public var model: String

    /// API key
    public var apiKey: String

    /// Base URL (for Ollama/OpenRouter)
    public var baseURL: String

    /// Validation error message
    public var validationError: String?

    /// Available providers
    public let availableProviders: [LLMProvider]

    /// Whether the form is valid
    public var isValid: Bool {
        !name.isEmpty && !model.isEmpty && !apiKey.isEmpty && validate()
    }

    /// Whether base URL is required for the selected provider
    public var requiresBaseURL: Bool {
        provider == .ollama || provider == .openrouter
    }

    /// Provider-specific help text
    public var providerHelpText: String {
        switch provider {
        case .openai:
            "Enter your OpenAI API key from platform.openai.com"
        case .anthropic:
            "Enter your Anthropic API key from console.anthropic.com"
        case .google:
            "Enter your Google AI API key from makersuite.google.com"
        case .openrouter:
            "Enter your OpenRouter API key and base URL"
        case .ollama:
            "Enter your Ollama base URL (e.g., http://localhost:11434)"
        case .appleIntelligence:
            "Apple Intelligence doesn't require an API key"
        }
    }

    /// Example model names for the selected provider
    public var exampleModels: String {
        switch provider {
        case .openai:
            "gpt-4o, gpt-4o-mini, o1"
        case .anthropic:
            "claude-3-5-sonnet-20241022, claude-3-5-haiku-20241022"
        case .google:
            "gemini-2.0-flash-exp, gemini-1.5-pro"
        case .openrouter:
            "openai/gpt-4o, anthropic/claude-3.5-sonnet"
        case .ollama:
            "llama3.1, mistral, codellama"
        case .appleIntelligence:
            "apple-intelligence"
        }
    }

    /// Validate the form
    /// - Returns: True if valid, false otherwise (sets validationError)
    @discardableResult
    public func validate() -> Bool {
        validationError = nil

        if name.trimmingCharacters(in: .whitespaces).isEmpty {
            validationError = "Name is required"
            return false
        }

        if model.trimmingCharacters(in: .whitespaces).isEmpty {
            validationError = "Model is required"
            return false
        }

        if provider != .appleIntelligence, apiKey.trimmingCharacters(in: .whitespaces).isEmpty {
            validationError = "API key is required"
            return false
        }

        if requiresBaseURL, baseURL.trimmingCharacters(in: .whitespaces).isEmpty {
            validationError = "Base URL is required for this provider"
            return false
        }

        // Validate base URL format if provided
        if !baseURL.isEmpty {
            guard let url = URL(string: baseURL),
                  url.scheme == "http" || url.scheme == "https"
            else {
                validationError = "Invalid base URL format"
                return false
            }
        }

        return true
    }

    /// Create LLMConfig from form data
    /// - Parameter id: Optional ID for the config (defaults to UUID)
    /// - Returns: The created LLMConfig
    public func createConfig(id: String? = nil) -> LLMConfig {
        LLMConfig(
            name: name.trimmingCharacters(in: .whitespaces),
            provider: provider,
            model: model.trimmingCharacters(in: .whitespaces),
            baseURL: baseURL.isEmpty ? nil : baseURL.trimmingCharacters(in: .whitespaces),
            id: id ?? configID ?? UUID().uuidString
        )
    }

    // MARK: Private

    private var configID: String?
}
