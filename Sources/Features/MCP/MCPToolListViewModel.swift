//
// MCPToolListViewModel.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation
import Observation
import TENEXCore

/// View model for the MCP tool list screen
@MainActor
@Observable
public final class MCPToolListViewModel {
    // MARK: Lifecycle

    /// Initialize the MCP tool list view model
    /// - Parameter dataStore: The centralized data store
    public init(dataStore: DataStore) {
        self.dataStore = dataStore
    }

    // MARK: Public

    /// All available MCP tools
    public var tools: [MCPTool] {
        dataStore.tools
    }

    /// Whether tools are currently being loaded
    public var isLoading: Bool {
        dataStore.isLoadingTools
    }

    // MARK: Private

    @ObservationIgnored private let dataStore: DataStore
}
