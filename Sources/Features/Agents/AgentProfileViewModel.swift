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

    /// Initialize with an agent definition
    /// - Parameters:
    ///   - ndk: The NDK instance
    ///   - agentDefinition: The existing agent definition (if available)
    ///   - projectAgent: The project agent (if available, used to fetch definition)
    public init(ndk: some NDKSubscribing & NDKEventQuerying, agentDefinition: NDKAgentDefinition? = nil, projectAgent: ProjectAgent? = nil) {
        self.ndk = ndk
        self.agentDefinition = agentDefinition
        self.projectAgent = projectAgent
    }

    // MARK: Public

    /// The agent definition to display (Kind 4199)
    public private(set) var agentDefinition: NDKAgentDefinition?

    /// The agent metadata (Kind 0)
    public private(set) var agentMetadata: NDKUserMetadata?

    /// The project agent info (from ProjectStatus)
    public let projectAgent: ProjectAgent?

    /// Loading state
    public private(set) var isLoading = false

    /// Error message
    public private(set) var errorMessage: String?

    /// Computed property for name (prefer definition, then metadata, then project agent)
    public var name: String {
        agentDefinition?.name ?? agentMetadata?.name ?? projectAgent?.name ?? "Unknown Agent"
    }

    /// Computed property for description
    public var description: String {
        agentDefinition?.description ?? agentMetadata?.about ?? "No description provided"
    }

    /// Computed property for instructions
    public var instructions: String? {
        // Kind 4199 instructions
        if let instructions = agentDefinition?.instructions, !instructions.isEmpty {
            return instructions
        }
        // Kind 0 metadata might have instructions or systemPrompt
        // NDKUserMetadata might not expose raw content easily depending on implementation
        // But if we had access to raw JSON, we'd check 'instructions' or 'systemPrompt'
        // For now, we rely on what NDKUserMetadata exposes or extend it if needed.
        // Assuming we only get standard fields for now unless we parse content manually.
        return nil
    }

    /// Load the agent profile
    public func load() async {
        guard let projectAgent else { return }

        isLoading = true
        errorMessage = nil

        do {
            // 1. Fetch Agent Definition (Kind 4199)
            let definitionFilter = NDKFilter(
                kinds: [4199],
                authors: [projectAgent.pubkey],
                limit: 1
            )

            // 2. Fetch Metadata (Kind 0)
            let metadataFilter = NDKFilter(
                kinds: [0],
                authors: [projectAgent.pubkey],
                limit: 1
            )

            let events = try await ndk.queryEvents(filters: [definitionFilter, metadataFilter])

            // Process Definition
            if let defEvent = events.filter({ $0.kind == 4199 }).max(by: { $0.createdAt < $1.createdAt }) {
                agentDefinition = NDKAgentDefinition(from: defEvent)
            }

            // Process Metadata
            if let metaEvent = events.filter({ $0.kind == 0 }).max(by: { $0.createdAt < $1.createdAt }) {
                agentMetadata = NDKUserMetadata(from: metaEvent)
            }

            if agentDefinition == nil && agentMetadata == nil {
                errorMessage = "Agent profile not found."
            }

        } catch {
            Logger().error("Failed to load agent profile: \(error.localizedDescription)")
            errorMessage = "Failed to load agent profile."
        }

        isLoading = false
    }

    // MARK: Private

    private let ndk: some NDKSubscribing & NDKEventQuerying
}
