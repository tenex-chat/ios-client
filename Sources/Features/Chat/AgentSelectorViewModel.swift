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
/// Supports both agent selection and hashtag selection (mutually exclusive)
@MainActor
@Observable
public final class AgentSelectorViewModel: Identifiable {
    // MARK: Lifecycle

    /// Initialize the agent selector view model with data store
    /// - Parameters:
    ///   - dataStore: The data store containing project statuses
    ///   - projectReference: The project coordinate to get agents for
    ///   - defaultAgentPubkey: Optional default agent pubkey to preselect
    ///   - availableHashtags: List of available hashtags for selection
    public init(
        dataStore: DataStore,
        projectReference: String,
        defaultAgentPubkey: String? = nil,
        availableHashtags: [String] = []
    ) {
        self.dataStore = dataStore
        self.projectReference = projectReference
        self.agentsList = nil
        self.availableHashtags = availableHashtags
        let currentAgents = Self
            .sortAgents(dataStore.getProjectStatus(projectCoordinate: projectReference)?.agents ?? [])
        self.selectedAgentPubkey = defaultAgentPubkey ?? currentAgents.first?.pubkey
    }

    /// Initialize the agent selector view model with a static list of agents
    /// - Parameters:
    ///   - agents: The list of agents to display
    ///   - defaultAgentPubkey: Optional default agent pubkey to preselect
    ///   - availableHashtags: List of available hashtags for selection
    public init(agents: [ProjectAgent], defaultAgentPubkey: String? = nil, availableHashtags: [String] = []) {
        self.dataStore = nil
        self.projectReference = nil
        self.agentsList = Self.sortAgents(agents)
        self.availableHashtags = availableHashtags
        self.selectedAgentPubkey = defaultAgentPubkey ?? self.agentsList?.first?.pubkey
    }

    // MARK: Public

    public let id = UUID()

    /// The currently selected agent pubkey (nil when hashtag is selected)
    public private(set) var selectedAgentPubkey: String?

    /// The currently selected hashtag (nil when agent is selected)
    public private(set) var selectedHashtag: String?

    /// Available hashtags for selection
    public var availableHashtags: [String]

    /// Whether the selector sheet is presented
    public var isPresented = false

    /// Whether the user has manually selected an agent (to prevent auto-updates)
    private var hasManualSelection = false

    /// List of online agents from ProjectStatus (sorted: PM first, then alphabetical)
    public var agents: [ProjectAgent] {
        if let agentsList {
            return agentsList
        }
        guard let dataStore, let projectReference else {
            return []
        }
        return Self.sortAgents(dataStore.getProjectStatus(projectCoordinate: projectReference)?.agents ?? [])
    }

    /// Get the currently selected agent
    public var selectedAgent: ProjectAgent? {
        guard let selectedAgentPubkey else {
            return nil
        }
        return self.agents.first { $0.pubkey == selectedAgentPubkey }
    }

    /// Whether a hashtag is selected (mutually exclusive with agent)
    public var hasHashtagSelected: Bool {
        selectedHashtag != nil
    }

    /// Select an agent by pubkey (clears hashtag selection)
    /// - Parameter pubkey: The agent's Nostr pubkey
    public func selectAgent(_ pubkey: String) {
        self.selectedAgentPubkey = pubkey
        self.selectedHashtag = nil
        self.hasManualSelection = true
    }

    /// Select a hashtag (clears agent selection)
    /// - Parameter hashtag: The hashtag to select
    public func selectHashtag(_ hashtag: String) {
        self.selectedHashtag = hashtag.lowercased()
        self.selectedAgentPubkey = nil
        self.hasManualSelection = true
    }

    /// Clear hashtag selection and optionally restore agent
    public func clearHashtag() {
        self.selectedHashtag = nil
        // Optionally restore first agent as default
        if selectedAgentPubkey == nil {
            self.selectedAgentPubkey = agents.first?.pubkey
        }
    }

    /// Update the default agent (auto-selection from last message)
    /// Only updates if the user hasn't manually selected an agent or hashtag
    /// - Parameter pubkey: The agent's Nostr pubkey to set as default
    public func updateDefaultAgent(_ pubkey: String?) {
        guard !hasManualSelection else {
            return
        }
        self.selectedAgentPubkey = pubkey
    }

    /// Reset manual selection flag (e.g., when starting a new thread)
    public func resetManualSelection() {
        self.hasManualSelection = false
        self.selectedHashtag = nil
    }

    /// Present the agent selector sheet
    public func presentSelector() {
        self.isPresented = true
    }

    /// Dismiss the agent selector sheet
    public func dismissSelector() {
        self.isPresented = false
    }

    // MARK: Private

    @ObservationIgnored private let dataStore: DataStore?
    @ObservationIgnored private let projectReference: String?
    @ObservationIgnored private let agentsList: [ProjectAgent]?

    /// Sort agents: PM first, then alphabetically by name
    private static func sortAgents(_ agents: [ProjectAgent]) -> [ProjectAgent] {
        agents.sorted { lhs, rhs in
            // PM always comes first
            if lhs.isPM != rhs.isPM {
                return lhs.isPM
            }
            // Otherwise sort alphabetically by name
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }
}
