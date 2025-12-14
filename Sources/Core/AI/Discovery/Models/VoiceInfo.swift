//
// VoiceInfo.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation

// MARK: - VoiceLabels

/// Metadata labels for a voice
public struct VoiceLabels: Sendable, Equatable, Codable {
    // MARK: Lifecycle

    public init(
        gender: String? = nil,
        accent: String? = nil,
        age: String? = nil,
        useCase: String? = nil
    ) {
        self.gender = gender
        self.accent = accent
        self.age = age
        self.useCase = useCase
    }

    // MARK: Public

    /// Voice gender (e.g., "male", "female", "neutral")
    public let gender: String?

    /// Voice accent (e.g., "american", "british", "australian")
    public let accent: String?

    /// Age range (e.g., "young", "middle aged", "old")
    public let age: String?

    /// Intended use case (e.g., "narration", "conversational")
    public let useCase: String?
}

// MARK: - VoiceInfo

/// Information about an available TTS voice
public struct VoiceInfo: Identifiable, Sendable, Equatable {
    // MARK: Lifecycle

    public init(
        id: String,
        name: String,
        description: String? = nil,
        labels: VoiceLabels? = nil,
        previewURL: URL? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.labels = labels
        self.previewURL = previewURL
    }

    // MARK: Public

    /// Unique voice identifier
    public let id: String

    /// Display name for the voice
    public let name: String

    /// Optional description
    public let description: String?

    /// Voice metadata labels for filtering
    public let labels: VoiceLabels?

    /// URL to preview audio sample
    public let previewURL: URL?
}
