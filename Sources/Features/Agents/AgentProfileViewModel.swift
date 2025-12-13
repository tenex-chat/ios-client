//
// AgentProfileViewModel.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation
import NDKSwiftCore
import Observation
import OSLog
import TENEXCore

@MainActor
@Observable
public final class AgentProfileViewModel {
    // MARK: Lifecycle

    /// Initialize with a project agent
    /// - Parameters:
    ///   - ndk: The NDK instance
    ///   - projectAgent: The project agent info
    public init(ndk: some NDKSubscribing & NDKEventQuerying, projectAgent: ProjectAgent) {
        self.ndk = ndk
        self.projectAgent = projectAgent
    }

    // MARK: Public

    /// The agent metadata (Kind 0)
    public private(set) var agentMetadata: NDKUserMetadata?

    /// The project agent info (from ProjectStatus)
    public let projectAgent: ProjectAgent

    /// Loading state
    public private(set) var isLoading = false

    /// Error message
    public private(set) var errorMessage: String?

    /// Computed property for name
    public var name: String {
        agentMetadata?.name ?? projectAgent.name
    }

    /// Computed property for description
    public var description: String {
        agentMetadata?.about ?? "No description provided"
    }

    /// Computed property for instructions
    public var instructions: String? {
        agentMetadata?.instructions
    }

    /// Load the agent profile (Metadata only)
    public func load() async {
        isLoading = true
        errorMessage = nil

        do {
            // Fetch Metadata (Kind 0)
            let metadataFilter = NDKFilter(
                kinds: [0],
                authors: [projectAgent.pubkey],
                limit: 1
            )

            let events = try await ndk.queryEvents(filters: [metadataFilter])

            if let metaEvent = events.first {
                agentMetadata = NDKUserMetadata(from: metaEvent)
            }

            // Note: We don't error if metadata is missing, we just show ProjectAgent info

        } catch {
            Logger().error("Failed to load agent metadata: \(error.localizedDescription)")
            // Non-blocking error, we still have ProjectAgent info
        }

        isLoading = false
    }

    // MARK: Private

    private let ndk: some NDKSubscribing & NDKEventQuerying
}
