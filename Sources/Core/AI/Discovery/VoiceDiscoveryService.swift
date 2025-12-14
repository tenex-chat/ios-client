//
// VoiceDiscoveryService.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation
import TENEXCore

// MARK: - VoiceDiscoveryService

/// Service for discovering available voices from TTS providers
public protocol VoiceDiscoveryService: Sendable {
    /// Fetch available voices for a provider
    /// - Parameters:
    ///   - provider: The TTS provider
    ///   - apiKey: API key for authentication
    /// - Returns: Array of available voices
    func fetchVoices(provider: TTSProvider, apiKey: String) async throws -> [VoiceInfo]
}

// MARK: - VoiceDiscoveryServiceImpl

/// Thread-safe actor implementation with 24-hour caching
public actor VoiceDiscoveryServiceImpl: VoiceDiscoveryService {
    // MARK: Lifecycle

    public init() {}

    // MARK: Public

    public func fetchVoices(provider: TTSProvider, apiKey: String) async throws -> [VoiceInfo] {
        // Check cache
        let cacheKey = "\(provider.rawValue)-\(apiKey.prefix(8))"
        if let cached = cache[cacheKey], Date().timeIntervalSince(cached.timestamp) < cacheTTL {
            return cached.voices
        }

        // Fetch from provider
        let voices = try await fetchFromProvider(provider, apiKey: apiKey)

        // Update cache
        cache[cacheKey] = CachedVoices(voices: voices, timestamp: Date())
        return voices
    }

    // MARK: Private

    private struct CachedVoices {
        let voices: [VoiceInfo]
        let timestamp: Date
    }

    private var cache: [String: CachedVoices] = [:]
    private let cacheTTL: TimeInterval = 24 * 60 * 60 // 24 hours

    private func fetchFromProvider(_ provider: TTSProvider, apiKey: String) async throws -> [VoiceInfo] {
        switch provider {
        case .elevenlabs:
            return try await fetchElevenLabsVoices(apiKey: apiKey)
        case .openai,
             .system:
            throw VoiceDiscoveryError.unsupportedProvider
        }
    }

    private func fetchElevenLabsVoices(apiKey: String) async throws -> [VoiceInfo] {
        guard let url = URL(string: "https://api.elevenlabs.io/v1/voices") else {
            throw VoiceDiscoveryError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "xi-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw VoiceDiscoveryError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw VoiceDiscoveryError.apiError(
                statusCode: httpResponse.statusCode,
                message: String(data: data, encoding: .utf8)
            )
        }

        let result = try JSONDecoder().decode(ElevenLabsVoicesResponse.self, from: data)
        return result.voices.map { voice in
            let labels = VoiceLabels(
                gender: voice.labels?.gender,
                accent: voice.labels?.accent,
                age: voice.labels?.age,
                useCase: voice.labels?.useCase
            )

            let descriptionParts = [
                voice.labels?.age,
                voice.labels?.gender,
                voice.labels?.accent,
                voice.labels?.description,
            ].compactMap(\.self)

            return VoiceInfo(
                id: voice.voiceID,
                name: voice.name,
                description: descriptionParts.isEmpty ? nil : descriptionParts.joined(separator: " "),
                labels: labels,
                previewURL: voice.previewURL.flatMap { URL(string: $0) }
            )
        }
    }
}
