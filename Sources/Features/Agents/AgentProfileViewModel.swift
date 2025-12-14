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

    private(set) var profileSubscription: NDKSubscription<NDKUserMetadata>?
    private(set) var eventsSubscription: NDKSubscription<NDKEvent>?

    /// Computed properties from profile subscription
    var agentName: String? {
        profileSubscription?.data.first?.name
    }

    var agentAbout: String? {
        profileSubscription?.data.first?.about
    }

    var agentPicture: String? {
        profileSubscription?.data.first?.picture
    }

    /// Events are already deduplicated and managed by NDKSubscription
    var events: [NDKEvent] {
        eventsSubscription?.data.sorted { $0.createdAt > $1.createdAt } ?? []
    }

    func startSubscriptions() {
        // Subscribe to agent's profile (kind:0) and transform to NDKUserMetadata
        // Uses cacheWithNetwork to leverage NostrDB cache
        profileSubscription = ndk.subscribe(
            filter: NDKFilter(authors: [pubkey], kinds: [0], limit: 1),
            cachePolicy: .cacheWithNetwork
        ) { event in
            NDKUserMetadata(event: event, ndk: self.ndk)
        }

        // Subscribe to all events from this agent
        eventsSubscription = ndk.subscribe(
            filter: NDKFilter(authors: [pubkey], limit: 50),
            cachePolicy: .cacheWithNetwork
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
