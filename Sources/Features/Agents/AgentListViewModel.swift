//
// AgentListViewModel.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Combine
import Foundation
import NDKSwiftCore

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
    @Published public var isLoading = false
    @Published public var error: String?

    public func fetchAgents() {
        isLoading = true

        let filter = NDKFilter(kinds: [4199], limit: 100)

        Task {
            do {
                let subscription = ndk.subscribeToEvents(filters: [filter])
                var collectedAgents: [AgentDefinition] = []

                for try await event in subscription {
                    if let agent = AgentDefinition.from(event: event) {
                        collectedAgents.append(agent)
                    }
                }

                await MainActor.run {
                    self.agents = collectedAgents
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
}
