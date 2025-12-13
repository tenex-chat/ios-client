//
// AgentSelectorViewModel.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation
import Observation

// MARK: - AgentInfo

/// Information about an agent
public struct AgentInfo: Identifiable, Equatable {
    // MARK: Lifecycle

    /// Initialize agent info
    /// - Parameters:
    ///   - id: The agent identifier
    ///   - name: The agent name
    ///   - icon: The icon name (SF Symbol)
    public init(id: String, name: String, icon: String) {
        self.id = id
        self.name = name
        self.icon = icon
    }

    // MARK: Public

    /// The agent identifier
    public let id: String

    /// The agent name
    public let name: String

    /// The icon name (SF Symbol)
    public let icon: String
}

// MARK: - AgentSelectorViewModel

/// View model for agent selector
@MainActor
@Observable
public final class AgentSelectorViewModel {
    // MARK: Lifecycle

    /// Initialize the agent selector view model
    /// - Parameter availableAgents: List of available agents
    public init(availableAgents: [AgentInfo]) {
        self.availableAgents = availableAgents
    }

    // MARK: Public

    /// List of available agents
    public let availableAgents: [AgentInfo]

    /// The currently selected agent ID
    public private(set) var selectedAgentID: String?

    /// Whether the selector sheet is presented
    public var isPresented = false

    /// Get the currently selected agent info
    public var selectedAgent: AgentInfo? {
        guard let selectedAgentID else {
            return nil
        }
        return availableAgents.first { $0.id == selectedAgentID }
    }

    /// Select an agent
    /// - Parameter agentId: The agent identifier
    public func selectAgent(_ agentID: String) {
        selectedAgentID = agentID
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
