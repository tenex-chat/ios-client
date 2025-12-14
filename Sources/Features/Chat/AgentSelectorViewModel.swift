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
    ///   - dataStore: The data store containing project statuses
    ///   - projectReference: The project coordinate to get agents for
    ///   - defaultAgentPubkey: Optional default agent pubkey to preselect
    public init(dataStore: DataStore, projectReference: String, defaultAgentPubkey: String? = nil) {
        self.dataStore = dataStore
        self.projectReference = projectReference
        let currentAgents = dataStore.getProjectStatus(projectCoordinate: projectReference)?.agents ?? []
        selectedAgentPubkey = defaultAgentPubkey ?? currentAgents.first?.pubkey
    }

    // MARK: Public

    /// The currently selected agent pubkey
    public private(set) var selectedAgentPubkey: String?

    /// Whether the selector sheet is presented
    public var isPresented = false

    /// List of online agents from ProjectStatus
    public var agents: [ProjectAgent] {
        dataStore.getProjectStatus(projectCoordinate: projectReference)?.agents ?? []
    }

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

    /// Present the agent selector sheet
    public func presentSelector() {
        isPresented = true
    }

    /// Dismiss the agent selector sheet
    public func dismissSelector() {
        isPresented = false
    }

    // MARK: Private

    @ObservationIgnored private let dataStore: DataStore
    @ObservationIgnored private let projectReference: String
}
