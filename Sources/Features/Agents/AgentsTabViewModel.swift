//
// AgentsTabViewModel.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation
import NDKSwiftCore
import Observation
import TENEXCore

// MARK: - AgentsTabViewModel

/// View model for the Agents Tab
/// Shows online agents from ProjectStatus (kind:24010)
/// Uses real-time subscriptions to continuously update as events arrive
@MainActor
@Observable
public final class AgentsTabViewModel {
    // MARK: Lifecycle

    /// Initialize the agents tab view model
    /// - Parameters:
    ///   - ndk: The NDK instance
    ///   - projectID: The project identifier
    public init(ndk: NDK, projectID: String) {
        self.ndk = ndk
        self.projectID = projectID
    }

    // MARK: Public

    /// Online agents from ProjectStatus
    public var agents: [ProjectAgent] {
        // Get the latest ProjectStatus event and extract agents
        subscription?.data.first?.agents ?? []
    }

    /// Whether initial load is in progress
    public var isLoading: Bool {
        subscription?.isLoading ?? false
    }

    /// Error message if subscription failed
    public var errorMessage: String? {
        subscription?.error?.localizedDescription
    }

    /// Start subscribing to ProjectStatus events
    /// Continuously updates agents as new events arrive
    public func subscribe() {
        let filter = ProjectStatus.filter(for: projectID)
        subscription = ndk.subscribe(
            filter: filter,
            cachePolicy: .cacheWithNetwork
        ) { event in
            ProjectStatus.from(event: event)
        }
    }

    /// Refresh agents by restarting subscription
    public func refresh() {
        subscribe()
    }

    // MARK: Internal

    private(set) var subscription: NDKSubscription<ProjectStatus>?

    let ndk: NDK

    // MARK: Private

    private let projectID: String
}
