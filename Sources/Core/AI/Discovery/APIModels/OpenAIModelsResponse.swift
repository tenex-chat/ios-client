//
// OpenAIModelsResponse.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation

// MARK: - OpenAIModelsResponse

/// Response from OpenAI /v1/models endpoint
struct OpenAIModelsResponse: Decodable {
    let data: [OpenAIModel]
}

// MARK: - OpenAIModel

struct OpenAIModel: Decodable {
    enum CodingKeys: String, CodingKey {
        case id
        case ownedBy = "owned_by"
    }

    let id: String
    let ownedBy: String?
}
