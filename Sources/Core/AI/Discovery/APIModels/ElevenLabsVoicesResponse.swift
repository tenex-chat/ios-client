//
// ElevenLabsVoicesResponse.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation

// MARK: - ElevenLabsVoicesResponse

/// Response from ElevenLabs /v1/voices endpoint
struct ElevenLabsVoicesResponse: Decodable {
    let voices: [ElevenLabsVoice]
}

// MARK: - ElevenLabsVoice

struct ElevenLabsVoice: Decodable {
    enum CodingKeys: String, CodingKey {
        case voiceID = "voice_id"
        case name
        case labels
        case previewURL = "preview_url"
    }

    let voiceID: String
    let name: String
    let labels: ElevenLabsVoiceLabels?
    let previewURL: String?
}

// MARK: - ElevenLabsVoiceLabels

struct ElevenLabsVoiceLabels: Decodable {
    enum CodingKeys: String, CodingKey {
        case gender
        case accent
        case age
        case description
        case useCase = "use_case"
    }

    let gender: String?
    let accent: String?
    let age: String?
    let description: String?
    let useCase: String?
}
