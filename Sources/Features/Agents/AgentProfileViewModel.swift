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

    /// Agent name fallback (shortened pubkey)
    var agentName: String? {
        String(pubkey.prefix(8))
    }

    /// Events sorted by most recent first (NDKFeed already handles deduplication)
    var events: [NDKEvent] {
        feed.events
    }

    func startSubscriptions() {
        // Subscribe to all events from this agent
        let subscription = ndk.subscribe(
            filter: NDKFilter(authors: [pubkey], limit: 50)
        )
        feed.observe(subscription)
    }

    // MARK: Private

    private let pubkey: String
    private let ndk: NDK
    private let feed = NDKFeed()
}
