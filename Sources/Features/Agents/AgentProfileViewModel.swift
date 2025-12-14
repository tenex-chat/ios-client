//
// AgentProfileViewModel.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation
import NDKSwiftCore
import OSLog

// MARK: - AgentProfileViewModel

/// ViewModel for agent profile view
@Observable
final class AgentProfileViewModel {
    // MARK: Lifecycle

    init(pubkey: String, ndk: NDK) {
        self.pubkey = pubkey
        self.ndk = ndk
    }

    // MARK: Internal

    private(set) var agentName: String?
    private(set) var agentRole: String?
    private(set) var events: [NDKEvent] = []
    private(set) var isLoading = false

    func loadAgentInfo() async {
        isLoading = true
        defer { isLoading = false }

        do {
            guard let publicKey = PublicKey(hex: pubkey) else {
                Logger().error("Invalid pubkey format: \(pubkey)")
                return
            }

            let filter = Filter(
                authors: [publicKey],
                kinds: [.custom(4199)]
            )

            let events = try await ndk.fetch(filter: filter)

            if let agentEvent = events.first {
                extractAgentInfo(from: agentEvent)
            }

            await loadEvents()
        } catch {
            Logger().error("Failed to load agent info: \(error.localizedDescription)")
        }
    }

    func refreshEvents() async {
        await loadEvents()
    }

    // MARK: Private

    private let pubkey: String
    private let ndk: NDK

    private func extractAgentInfo(from event: NDKEvent) {
        for tag in event.tags {
            switch tag.id {
            case "title",
                 "name":
                if let name = tag.value {
                    agentName = name
                }
            case "role":
                if let role = tag.value {
                    agentRole = role
                }
            default:
                break
            }
        }

        if agentName == nil, !event.content.isEmpty {
            agentName = "Agent"
        }
    }

    private func loadEvents() async {
        do {
            guard let publicKey = PublicKey(hex: pubkey) else {
                Logger().error("Invalid pubkey format: \(pubkey)")
                return
            }

            let filter = Filter(
                authors: [publicKey],
                limit: 50
            )

            let fetchedEvents = try await ndk.fetch(filter: filter)
            events = fetchedEvents.sorted { $0.createdDate > $1.createdDate }
        } catch {
            Logger().error("Failed to load events: \(error.localizedDescription)")
        }
    }
}
