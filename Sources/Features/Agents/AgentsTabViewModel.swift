//
// AgentsTabViewModel.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation
import NDKSwiftCore
import Observation
import OSLog
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
    public private(set) var agents: [ProjectAgent] = []

    /// Whether initial load is in progress
    public private(set) var isLoading = false

    /// Error message if subscription failed
    public private(set) var errorMessage: String?

    /// Whether subscription is active
    public private(set) var isSubscribed = false

    /// Start subscribing to ProjectStatus events
    /// Continuously updates agents as new events arrive
    public func subscribe() async {
        guard !isSubscribed else {
            return
        }

        isLoading = true
        isSubscribed = true
        errorMessage = nil

        do {
            let filter = ProjectStatus.filter(for: projectID)
            let subscription = ndk.subscribeToEvents(filters: [filter])

            // Continuously process events - no break, real-time updates
            for try await event in subscription {
                if let status = ProjectStatus.from(event: event) {
                    agents = status.agents
                    // First event received, no longer in initial loading state
                    if isLoading {
                        isLoading = false
                    }
                }
            }

            // Subscription ended (e.g., EOSE or cancelled)
            isSubscribed = false
        } catch {
            Logger().error("Failed to subscribe to agents: \(error.localizedDescription)")
            errorMessage = "Failed to load agents"
            isLoading = false
            isSubscribed = false
        }
    }

    /// Refresh agents by restarting subscription
    public func refresh() async {
        isSubscribed = false
        agents = []
        await subscribe()
    }

    // MARK: Internal

    let ndk: NDK

    // MARK: Private

    private let projectID: String
}
