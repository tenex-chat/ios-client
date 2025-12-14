//
// OpenRouterModelsResponse.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation

// MARK: - OpenRouterModelsResponse

/// Response from OpenRouter /api/v1/models endpoint
struct OpenRouterModelsResponse: Decodable {
    let data: [OpenRouterModel]
}

// MARK: - OpenRouterModel

struct OpenRouterModel: Decodable {
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case contextLength = "context_length"
    }

    let id: String
    let name: String?
    let description: String?
    let contextLength: Int?
}
