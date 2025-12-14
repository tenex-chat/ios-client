//
// OllamaModelsResponse.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation

// MARK: - OllamaModelsResponse

/// Response from Ollama /api/tags endpoint
struct OllamaModelsResponse: Decodable {
    let models: [OllamaModel]?
}

// MARK: - OllamaModel

struct OllamaModel: Decodable {
    let name: String
    let size: Int?
}
