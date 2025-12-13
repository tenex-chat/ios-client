//
// AgentProfileViewModel.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation
import NDKSwiftCore
import Observation
import OSLog
import TENEXCore

@MainActor
@Observable
public final class AgentProfileViewModel {
    // MARK: Lifecycle

    /// Initialize with an agent definition
    /// - Parameters:
    ///   - ndk: The NDK instance
    ///   - agentDefinition: The existing agent definition (if available)
    ///   - projectAgent: The project agent (if available, used to fetch definition)
    public init(ndk: some NDKSubscribing & NDKEventQuerying, agentDefinition: NDKAgentDefinition? = nil, projectAgent: ProjectAgent? = nil) {
        self.ndk = ndk
        self.agentDefinition = agentDefinition
        self.projectAgent = projectAgent
    }

    // MARK: Public

    /// The agent definition to display
    public private(set) var agentDefinition: NDKAgentDefinition?

    /// The project agent info (if available)
    public let projectAgent: ProjectAgent?

    /// Loading state
    public private(set) var isLoading = false

    /// Error message
    public private(set) var errorMessage: String?

    /// Load the agent definition
    public func load() async {
        guard agentDefinition == nil else { return }

        // If we have a project agent, try to find its definition
        // We look for kind 4199 events authored by the agent's pubkey
        if let projectAgent {
            isLoading = true
            errorMessage = nil

            do {
                // Fetch kind 4199 events from this author
                let filter = NDKFilter(
                    kinds: [4199],
                    authors: [projectAgent.pubkey],
                    limit: 1
                )

                // We want the latest definition
                // Since NDKSwift currently doesn't support complex sorting in query, we fetch and sort manually if needed
                // But usually limit 1 implies latest if the relay supports it (standard behavior)
                // However, NDKSwift's `queryEvents` might not guarantee order depending on implementation.
                // We'll fetch a few and sort.

                let events = try await ndk.queryEvents(filters: [filter])

                if let bestEvent = events.max(by: { $0.createdAt < $1.createdAt }) {
                    agentDefinition = NDKAgentDefinition(from: bestEvent)
                } else {
                    // If no definition found, we might want to try searching by name (d-tag) if the pubkey is different?
                    // For now, assume the agent pubkey authors its definition.
                    errorMessage = "Agent definition not found."
                }
            } catch {
                Logger().error("Failed to load agent definition: \(error.localizedDescription)")
                errorMessage = "Failed to load agent definition."
            }

            isLoading = false
        }
    }

    // MARK: Private

    private let ndk: some NDKSubscribing & NDKEventQuerying
}
