//
// VoiceSelectionViewModel.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import AVFoundation
import Foundation
import Observation
import TENEXCore

// MARK: - VoiceSelectionViewModel

/// View model for voice selection with filtering and preview
@MainActor
@Observable
public final class VoiceSelectionViewModel {
    // MARK: Lifecycle

    /// Initialize voice selection view model
    /// - Parameter voiceDiscovery: Service for discovering voices
    public init(voiceDiscovery: VoiceDiscoveryService = VoiceDiscoveryServiceImpl()) {
        self.voiceDiscovery = voiceDiscovery
    }

    // MARK: Public

    /// Filtered voices based on search and filters
    public var filteredVoices: [VoiceInfo] {
        availableVoices.filter { voice in
            // Search filter
            if !searchQuery.isEmpty {
                let query = searchQuery.lowercased()
                let matchesSearch = voice.name.lowercased().contains(query) ||
                    voice.description?.lowercased().contains(query) == true
                if !matchesSearch {
                    return false
                }
            }

            // Metadata filters
            if let gender = selectedGender, voice.labels?.gender != gender {
                return false
            }
            if let accent = selectedAccent, voice.labels?.accent != accent {
                return false
            }
            if let age = selectedAge, voice.labels?.age != age {
                return false
            }
            if let useCase = selectedUseCase, voice.labels?.useCase != useCase {
                return false
            }

            return true
        }
    }

    /// Available gender options from voices
    public var genderOptions: [String] {
        let genders = Set(availableVoices.compactMap { $0.labels?.gender })
        return Array(genders).sorted()
    }

    /// Available accent options from voices
    public var accentOptions: [String] {
        let accents = Set(availableVoices.compactMap { $0.labels?.accent })
        return Array(accents).sorted()
    }

    /// Available age options from voices
    public var ageOptions: [String] {
        let ages = Set(availableVoices.compactMap { $0.labels?.age })
        return Array(ages).sorted()
    }

    /// Available use case options from voices
    public var useCaseOptions: [String] {
        let useCases = Set(availableVoices.compactMap { $0.labels?.useCase })
        return Array(useCases).sorted()
    }

    /// Fetch voices from the provider
    /// - Parameters:
    ///   - provider: TTS provider
    ///   - apiKey: API key for authentication
    public func fetchVoices(provider: TTSProvider, apiKey: String) async {
        isLoadingVoices = true
        fetchError = nil

        do {
            availableVoices = try await voiceDiscovery.fetchVoices(provider: provider, apiKey: apiKey)
        } catch {
            fetchError = error.localizedDescription
            availableVoices = []
        }

        isLoadingVoices = false
    }

    /// Preview a voice by playing its preview URL
    /// - Parameter voiceInfo: The voice to preview
    public func previewVoice(_ voiceInfo: VoiceInfo) async {
        guard let previewURL = voiceInfo.previewURL else {
            return
        }

        previewingVoiceID = voiceInfo.id

        let playerItem = AVPlayerItem(url: previewURL)
        audioPlayer = AVPlayer(playerItem: playerItem)
        audioPlayer?.play()

        // Wait for playback to finish
        await withCheckedContinuation { continuation in
            NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: playerItem,
                queue: .main
            ) { _ in
                continuation.resume()
            }
        }

        previewingVoiceID = nil
    }

    /// Clear all filters
    public func clearFilters() {
        searchQuery = ""
        selectedGender = nil
        selectedAccent = nil
        selectedAge = nil
        selectedUseCase = nil
    }

    // MARK: Internal

    /// Available voices from discovery service
    private(set) var availableVoices: [VoiceInfo] = []

    /// Whether voices are currently being fetched
    private(set) var isLoadingVoices = false

    /// Error message from voice fetch
    private(set) var fetchError: String?

    /// Search query for filtering voices
    var searchQuery = ""

    /// Selected gender filter
    var selectedGender: String?

    /// Selected accent filter
    var selectedAccent: String?

    /// Selected age filter
    var selectedAge: String?

    /// Selected use case filter
    var selectedUseCase: String?

    /// Voice ID currently being previewed
    private(set) var previewingVoiceID: String?

    // MARK: Private

    private let voiceDiscovery: VoiceDiscoveryService
    private var audioPlayer: AVPlayer?
}
