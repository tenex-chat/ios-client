//
// ModelDiscoveryService.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation
import TENEXCore

// MARK: - ModelDiscoveryService

/// Service for discovering available models from AI providers
public protocol ModelDiscoveryService: Sendable {
    /// Fetch available models for a provider
    /// - Parameters:
    ///   - provider: The LLM provider
    ///   - apiKey: API key for authentication
    ///   - baseURL: Optional base URL for custom endpoints
    /// - Returns: Array of available models
    func fetchModels(
        provider: LLMProvider,
        apiKey: String,
        baseURL: String?
    ) async throws -> [ModelInfo]
}

// MARK: - ModelDiscoveryServiceImpl

/// Thread-safe actor implementation with 24-hour caching
public actor ModelDiscoveryServiceImpl: ModelDiscoveryService {
    // MARK: Lifecycle

    public init() {}

    // MARK: Public

    public func fetchModels(
        provider: LLMProvider,
        apiKey: String,
        baseURL: String?
    ) async throws -> [ModelInfo] {
        // Check cache
        let cacheKey = "\(provider.rawValue)-\(apiKey.suffix(8))"
        if let cached = cache[cacheKey], Date().timeIntervalSince(cached.timestamp) < cacheTTL {
            return cached.models
        }

        // Fetch from provider
        let models = try await fetchFromProvider(provider, apiKey: apiKey, baseURL: baseURL)

        // Update cache
        cache[cacheKey] = CachedModels(models: models, timestamp: Date())
        return models
    }

    // MARK: Private

    private struct CachedModels {
        let models: [ModelInfo]
        let timestamp: Date
    }

    private var cache: [String: CachedModels] = [:]
    private let cacheTTL: TimeInterval = 24 * 60 * 60 // 24 hours

    private func fetchFromProvider(
        _ provider: LLMProvider,
        apiKey: String,
        baseURL: String?
    ) async throws -> [ModelInfo] {
        switch provider {
        case .openai:
            return try await fetchOpenAIModels(apiKey: apiKey, baseURL: baseURL)
        case .openrouter:
            return try await fetchOpenRouterModels(apiKey: apiKey)
        case .ollama:
            return try await fetchOllamaModels(baseURL: baseURL ?? "http://localhost:11434")
        case .anthropic,
             .google,
             .appleIntelligence:
            throw ModelDiscoveryError.unsupportedProvider
        }
    }

    private func fetchOpenAIModels(apiKey: String, baseURL: String?) async throws -> [ModelInfo] {
        let urlString = "\(baseURL ?? "https://api.openai.com")/v1/models"
        guard let url = URL(string: urlString) else {
            throw ModelDiscoveryError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ModelDiscoveryError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw ModelDiscoveryError.apiError(
                statusCode: httpResponse.statusCode,
                message: String(data: data, encoding: .utf8)
            )
        }

        let result = try JSONDecoder().decode(OpenAIModelsResponse.self, from: data)
        let models = result.data.map { model in
            ModelInfo(
                id: model.id,
                name: model.id,
                description: model.ownedBy.map { "Owned by \($0)" },
                contextLength: nil
            )
        }
        return models.sorted { $0.id < $1.id }
    }

    private func fetchOpenRouterModels(apiKey: String) async throws -> [ModelInfo] {
        guard let url = URL(string: "https://openrouter.ai/api/v1/models") else {
            throw ModelDiscoveryError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ModelDiscoveryError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw ModelDiscoveryError.apiError(
                statusCode: httpResponse.statusCode,
                message: String(data: data, encoding: .utf8)
            )
        }

        let result = try JSONDecoder().decode(OpenRouterModelsResponse.self, from: data)
        let models = result.data.map { model in
            ModelInfo(
                id: model.id,
                name: model.name ?? model.id,
                description: model.description,
                contextLength: model.contextLength
            )
        }
        return models.sorted { $0.id < $1.id }
    }

    private func fetchOllamaModels(baseURL: String) async throws -> [ModelInfo] {
        guard let url = URL(string: "\(baseURL)/api/tags") else {
            throw ModelDiscoveryError.invalidResponse
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw ModelDiscoveryError.invalidResponse
            }

            guard httpResponse.statusCode == 200 else {
                throw ModelDiscoveryError.ollamaNotRunning
            }

            let result = try JSONDecoder().decode(OllamaModelsResponse.self, from: data)
            let models = (result.models ?? []).map { model in
                ModelInfo(
                    id: model.name,
                    name: model.name,
                    description: model.size.map { "Size: \(formatBytes($0))" },
                    contextLength: nil
                )
            }
            return models.sorted { $0.id < $1.id }
        } catch {
            throw ModelDiscoveryError.ollamaNotRunning
        }
    }

    private func formatBytes(_ bytes: Int) -> String {
        if bytes == 0 {
            return "0 Bytes"
        }
        let kilobyte = 1024.0
        let sizes = ["Bytes", "KB", "MB", "GB", "TB"]
        let index = Int(floor(log(Double(bytes)) / log(kilobyte)))
        let value = Double(bytes) / pow(kilobyte, Double(index))
        return String(format: "%.2f %@", value, sizes[index])
    }
}
