//
// AgentProfileViewModel.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation
import NDKSwiftCore

// MARK: - AgentProfileViewModel

/// ViewModel for agent profile view
@MainActor
@Observable
final class AgentProfileViewModel {
    // MARK: Lifecycle

    init(pubkey: String, ndk: NDK) {
        self.pubkey = pubkey
        self.ndk = ndk
    }

    // MARK: Internal

    private(set) var profileSubscription: NDKSubscription<NDKEvent>?
    private(set) var eventsSubscription: NDKSubscription<NDKEvent>?

    /// Computed properties from profile subscription
    var agentName: String? {
        guard let event = profileSubscription?.data.first,
              let data = event.content.data(using: .utf8),
              let metadata = try? JSONDecoder().decode(ProfileMetadata.self, from: data)
        else { return nil }
        return metadata.name
    }

    var agentAbout: String? {
        guard let event = profileSubscription?.data.first,
              let data = event.content.data(using: .utf8),
              let metadata = try? JSONDecoder().decode(ProfileMetadata.self, from: data)
        else { return nil }
        return metadata.about
    }

    var agentPicture: String? {
        guard let event = profileSubscription?.data.first,
              let data = event.content.data(using: .utf8),
              let metadata = try? JSONDecoder().decode(ProfileMetadata.self, from: data)
        else { return nil }
        return metadata.picture
    }

    /// Events are already deduplicated and managed by NDKSubscription
    var events: [NDKEvent] {
        eventsSubscription?.data.sorted { $0.createdAt > $1.createdAt } ?? []
    }

    func startSubscriptions() {
        // Subscribe to agent's profile (kind:0)
        profileSubscription = ndk.subscribe(
            filter: NDKFilter(authors: [pubkey], kinds: [0], limit: 1)
        )

        // Subscribe to all events from this agent
        eventsSubscription = ndk.subscribe(
            filter: NDKFilter(authors: [pubkey], limit: 50)
        )
    }

    func refresh() {
        // Just restart subscriptions - NDK will fetch fresh data
        startSubscriptions()
    }

    // MARK: Private

    private let pubkey: String
    private let ndk: NDK
}

// MARK: - ProfileMetadata

private struct ProfileMetadata: Codable {
    let name: String?
    let about: String?
    let picture: String?
}
