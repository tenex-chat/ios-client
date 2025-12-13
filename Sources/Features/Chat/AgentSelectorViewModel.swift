//
// AgentSelectorViewModel.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation
import Observation
import TENEXCore

// MARK: - AgentSelectorViewModel

/// View model for agent selector
/// Uses ProjectAgent from ProjectStatus (kind:24010) for online agents
@MainActor
@Observable
public final class AgentSelectorViewModel {
    // MARK: Lifecycle

    /// Initialize the agent selector view model
    /// - Parameters:
    ///   - agents: List of online agents from ProjectStatus
    ///   - defaultAgentPubkey: Optional default agent pubkey to preselect
    public init(agents: [ProjectAgent], defaultAgentPubkey: String? = nil) {
        self.agents = agents
        selectedAgentPubkey = defaultAgentPubkey ?? agents.first?.pubkey
    }

    // MARK: Public

    /// List of online agents from ProjectStatus
    public var agents: [ProjectAgent]

    /// The currently selected agent pubkey
    public private(set) var selectedAgentPubkey: String?

    /// Whether the selector sheet is presented
    public var isPresented = false

    /// Get the currently selected agent
    public var selectedAgent: ProjectAgent? {
        guard let selectedAgentPubkey else {
            return nil
        }
        return agents.first { $0.pubkey == selectedAgentPubkey }
    }

    /// Select an agent by pubkey
    /// - Parameter pubkey: The agent's Nostr pubkey
    public func selectAgent(_ pubkey: String) {
        selectedAgentPubkey = pubkey
    }

    /// Update the list of available agents
    /// - Parameter newAgents: Updated list of online agents
    public func updateAgents(_ newAgents: [ProjectAgent]) {
        agents = newAgents
        // Clear selection if selected agent is no longer available
        if let selectedAgentPubkey, !newAgents.contains(where: { $0.pubkey == selectedAgentPubkey }) {
            self.selectedAgentPubkey = newAgents.first?.pubkey
        }
    }

    /// Present the agent selector sheet
    public func presentSelector() {
        isPresented = true
    }

    /// Dismiss the agent selector sheet
    public func dismissSelector() {
        isPresented = false
    }
}
