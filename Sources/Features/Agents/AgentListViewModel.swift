//
// AgentListViewModel.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Combine
import Foundation
import NDKSwiftCore
import TENEXCore

@MainActor
public final class AgentListViewModel: ObservableObject {
    // MARK: Lifecycle

    public init(ndk: NDK) {
        self.ndk = ndk
        fetchAgents()
    }

    // MARK: Public

    public let ndk: NDK

    @Published public var agents: [AgentDefinition] = []
    @Published public var error: String?

    public func fetchAgents() {
        let filter = NDKFilter(kinds: [4199], limit: 100)

        Task {
            do {
                let subscription = ndk.subscribeToEvents(filters: [filter])
                var seenIDs: Set<String> = []

                for try await event in subscription {
                    // Deduplicate
                    guard !seenIDs.contains(event.id) else { continue }
                    seenIDs.insert(event.id)

                    if let agent = AgentDefinition.from(event: event) {
                        // Update UI immediately as events arrive
                        agents.append(agent)
                    }
                }
            } catch {
                self.error = error.localizedDescription
            }
        }
    }
}
