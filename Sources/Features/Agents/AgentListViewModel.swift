//
// AgentListViewModel.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation
import Observation
import TENEXCore

/// View model for the agent list screen
@MainActor
@Observable
public final class AgentListViewModel {
    // MARK: Lifecycle

    /// Initialize the agent list view model
    /// - Parameter dataStore: The centralized data store
    public init(dataStore: DataStore) {
        self.dataStore = dataStore
    }

    // MARK: Public

    /// All available agent definitions
    public var agents: [AgentDefinition] {
        dataStore.agents
    }

    /// Whether agents are currently being loaded
    public var isLoading: Bool {
        dataStore.isLoadingAgents
    }

    // MARK: Private

    @ObservationIgnored private let dataStore: DataStore
}
