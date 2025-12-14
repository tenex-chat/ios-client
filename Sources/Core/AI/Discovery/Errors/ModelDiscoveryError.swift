//
// ModelDiscoveryError.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation

/// Errors that can occur during model discovery
public enum ModelDiscoveryError: LocalizedError {
    case unsupportedProvider
    case apiError(statusCode: Int, message: String?)
    case ollamaNotRunning
    case invalidResponse
    case networkError(Error)

    // MARK: Public

    public var errorDescription: String? {
        switch self {
        case .unsupportedProvider:
            "This provider doesn't support automatic model discovery"
        case let .apiError(statusCode, message):
            if let message {
                "API error (\(statusCode)): \(message)"
            } else {
                "API error: HTTP \(statusCode)"
            }
        case .ollamaNotRunning:
            "Cannot connect to Ollama. Is it running?"
        case .invalidResponse:
            "Invalid response from API"
        case let .networkError(error):
            "Network error: \(error.localizedDescription)"
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .unsupportedProvider:
            "Enter the model name manually"
        case .apiError:
            "Check your API key and try again"
        case .ollamaNotRunning:
            "Start Ollama with: ollama serve"
        case .invalidResponse:
            "Please try again"
        case .networkError:
            "Check your internet connection"
        }
    }
}
