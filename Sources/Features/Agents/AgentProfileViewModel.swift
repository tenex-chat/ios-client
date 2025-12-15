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

    private(set) var eventsSubscription: NDKSubscription<NDKEvent>?

    /// Computed properties from profile
    var agentName: String? {
        self.ndk.getUser(self.pubkey)?.profile?.metadata?.name
    }

    var agentAbout: String? {
        self.ndk.getUser(self.pubkey)?.profile?.metadata?.about
    }

    var agentPicture: String? {
        self.ndk.getUser(self.pubkey)?.profile?.metadata?.picture
    }

    /// Events are already deduplicated and managed by NDKSubscription
    var events: [NDKEvent] {
        self.eventsSubscription?.data.sorted { $0.createdAt > $1.createdAt } ?? []
    }

    func startSubscriptions() {
        // Subscribe to all events from this agent
        self.eventsSubscription = self.ndk.subscribe(
            filter: NDKFilter(authors: [self.pubkey], limit: 50)
        )
    }

    // MARK: Private

    private let pubkey: String
    private let ndk: NDK
}
