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
        self.subscription?.data.first?.agents ?? []
    }

    /// Whether initial load is in progress
    public var isLoading: Bool {
        self.subscription?.isLoading ?? false
    }

    /// Error message if subscription failed
    public var errorMessage: String? {
        self.subscription?.error?.localizedDescription
    }

    /// Start subscribing to ProjectStatus events
    /// Continuously updates agents as new events arrive
    public func subscribe() {
        // Extract owner pubkey from project coordinate (format: "31933:pubkey:dTag")
        let ownerPubkey = self.extractOwnerPubkey(from: self.projectID)
        let filter = ProjectStatus.filter(for: ownerPubkey)
        self.subscription = self.ndk.subscribe(filter: filter) { event in
            // Only include status for this specific project
            guard let status = ProjectStatus.from(event: event),
                  status.projectCoordinate == self.projectID else {
                return nil
            }
            return status
        }
    }

    // MARK: Internal

    private(set) var subscription: NDKSubscription<ProjectStatus>?

    let ndk: NDK

    // MARK: Private

    private let projectID: String

    /// Extract owner pubkey from project coordinate
    /// - Parameter coordinate: Project coordinate in format "kind:pubkey:dTag"
    /// - Returns: The owner pubkey (middle component)
    private func extractOwnerPubkey(from coordinate: String) -> String {
        let components = coordinate.split(separator: ":")
        guard components.count >= 3 else {
            // Fallback: if not in expected format, return as-is
            return coordinate
        }
        return String(components[1])
    }
}
