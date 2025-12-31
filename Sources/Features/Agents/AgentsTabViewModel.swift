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
        latestStatus?.agents ?? []
    }

    /// Whether data is loading (subscription started but no data yet)
    public var isLoading: Bool {
        subscriptionStarted && latestStatus == nil
    }

    /// Start subscribing to ProjectStatus events
    /// Continuously updates agents as new events arrive
    public func subscribe() {
        subscriptionStarted = true
        // Extract owner pubkey from project coordinate (format: "31933:pubkey:dTag")
        let ownerPubkey = extractOwnerPubkey(from: projectID)
        let filter = ProjectStatus.filter(for: ownerPubkey)
        let subscription = ndk.subscribe(filter: filter)

        Task {
            for await batch in subscription.events {
                for event in batch {
                    guard let status = ProjectStatus.from(event: event),
                          status.projectCoordinate == projectID else {
                        continue
                    }
                    // Keep only the most recent status
                    if latestStatus == nil || status.createdAt > (latestStatus?.createdAt ?? .distantPast) {
                        latestStatus = status
                    }
                }
            }
        }
    }

    // MARK: Internal

    let ndk: NDK

    // MARK: Private

    private let projectID: String
    private var subscriptionStarted = false
    private var latestStatus: ProjectStatus?

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
