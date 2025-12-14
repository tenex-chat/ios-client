//
// ModelInfo.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation

/// Information about an available AI model
public struct ModelInfo: Identifiable, Sendable, Equatable {
    // MARK: Lifecycle

    public init(
        id: String,
        name: String,
        description: String? = nil,
        contextLength: Int? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.contextLength = contextLength
    }

    // MARK: Public

    /// Unique model identifier (e.g., "gpt-4o", "claude-3-5-sonnet-20241022")
    public let id: String

    /// Display name for the model
    public let name: String

    /// Optional description or metadata
    public let description: String?

    /// Context window size in tokens
    public let contextLength: Int?
}
