//
// DataStore.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation
import NDKSwiftCore
import Observation
import TENEXCore

/// Centralized data manager for high-level app entities
/// Owns all NDK subscriptions and provides reactive data access
@MainActor
@Observable
public final class DataStore {
    // MARK: Lifecycle

    /// Initialize the data store with NDK instance
    /// - Parameter ndk: The NDK instance for event subscriptions
    public init(ndk: NDK) {
        self.ndk = ndk
    }

    // MARK: Public

    // MARK: - Published State

    /// All projects owned by the authenticated user
    public private(set) var projects: [Project] = []

    /// All agent definitions (global catalog)
    public private(set) var agents: [AgentDefinition] = []

    /// All MCP tools (global catalog)
    public private(set) var tools: [MCPTool] = []

    /// Project statuses keyed by project ID
    public private(set) var projectStatuses: [String: ProjectStatus] = [:]

    /// All nudges (system prompt modifiers)
    public private(set) var nudges: [Nudge] = []

    /// Whether projects are currently loading
    public private(set) var isLoadingProjects = false

    /// Whether agents are currently loading
    public private(set) var isLoadingAgents = false

    /// Whether tools are currently loading
    public private(set) var isLoadingTools = false

    /// Whether nudges are currently loading
    public private(set) var isLoadingNudges = false

    /// Start subscriptions after authentication
    /// - Parameter userPubkey: The authenticated user's pubkey
    public func startSubscriptions(for userPubkey: String) {
        guard self.userPubkey != userPubkey else {
            return
        }

        // Clean up existing subscriptions
        stopSubscriptions()

        self.userPubkey = userPubkey

        // Start new subscriptions
        projectsTask = Task { await subscribeToProjects(userPubkey: userPubkey) }
        agentsTask = Task { await subscribeToAgents() }
        toolsTask = Task { await subscribeToTools() }
        statusTask = Task { await subscribeToProjectStatuses(userPubkey: userPubkey) }
        nudgesTask = Task { await subscribeToNudges() }
    }

    /// Stop all subscriptions and clear state
    public func stopSubscriptions() {
        projectsTask?.cancel()
        agentsTask?.cancel()
        toolsTask?.cancel()
        statusTask?.cancel()
        nudgesTask?.cancel()

        projectsTask = nil
        agentsTask = nil
        toolsTask = nil
        statusTask = nil
        nudgesTask = nil

        // Clear state
        projects = []
        agents = []
        tools = []
        projectStatuses = [:]
        nudges = []
        userPubkey = nil
    }

    // MARK: - Project Status

    /// Check if a project is currently online (has active, non-stale agents)
    /// - Parameter projectCoordinate: The project coordinate (kind:pubkey:dTag)
    /// - Returns: True if the project has online agents and status is not stale
    public func isProjectOnline(projectCoordinate: String) -> Bool {
        guard let status = projectStatuses[projectCoordinate] else {
            return false
        }
        return status.isOnline && !status.agents.isEmpty
    }

    /// Get the status for a project
    /// - Parameter projectCoordinate: The project coordinate (kind:pubkey:dTag)
    /// - Returns: The project status if available
    public func getProjectStatus(projectCoordinate: String) -> ProjectStatus? {
        projectStatuses[projectCoordinate]
    }

    // MARK: - Project Actions

    /// Start a project by publishing a kind 24000 event
    /// - Parameter project: The project to start
    public func startProject(_ project: Project) async throws {
        let event = try await NDKEventBuilder(ndk: ndk)
            .kind(24_000)
            .content("")
            .tag(["a", project.coordinate])
            .build()
        try await ndk.publish(event)
    }

    // MARK: Internal

    // MARK: - Testing Support

    /// Set project status for testing purposes only
    /// - Parameters:
    ///   - status: The project status to set
    ///   - coordinate: The project coordinate
    func setProjectStatus(_ status: ProjectStatus, for coordinate: String) {
        projectStatuses[coordinate] = status
    }

    // MARK: Private

    // MARK: - Dependencies

    private let ndk: NDK
    private var userPubkey: String?

    // MARK: - Subscription Tasks

    private var projectsTask: Task<Void, Never>?
    private var agentsTask: Task<Void, Never>?
    private var toolsTask: Task<Void, Never>?
    private var statusTask: Task<Void, Never>?
    private var nudgesTask: Task<Void, Never>?

    // MARK: - Private Subscription Methods

    private func subscribeToProjects(userPubkey: String) async {
        isLoadingProjects = true
        defer { isLoadingProjects = false }

        let filter = Project.filter(for: userPubkey)
        var projectsByID: [String: Project] = [:]
        var projectOrder: [String] = []

        let subscription = ndk.subscribe(filter: filter)

        for await event in subscription.events {
            if let project = Project.from(event: event) {
                if projectsByID[project.id] == nil {
                    projectOrder.append(project.id)
                }
                projectsByID[project.id] = project
                projects = projectOrder.compactMap { projectsByID[$0] }
            }
        }
    }

    private func subscribeToAgents() async {
        isLoadingAgents = true
        defer { isLoadingAgents = false }

        let filter = NDKFilter(kinds: [4199], limit: 100)
        let subscription = ndk.subscribe(filter: filter)
        var agentsByID: [String: AgentDefinition] = [:]

        for await event in subscription.events {
            if let agent = AgentDefinition.from(event: event) {
                agentsByID[agent.id] = agent
                agents = Array(agentsByID.values)
            }
        }
    }

    private func subscribeToTools() async {
        isLoadingTools = true
        defer { isLoadingTools = false }

        let filter = NDKFilter(kinds: [4200], limit: 100)
        let subscription = ndk.subscribe(filter: filter)
        var toolsByID: [String: MCPTool] = [:]

        for await event in subscription.events {
            if let tool = MCPTool.from(event: event) {
                toolsByID[tool.id] = tool
                tools = Array(toolsByID.values)
            }
        }
    }

    private func subscribeToProjectStatuses(userPubkey: String) async {
        let filter = ProjectStatus.filter(for: userPubkey)
        let subscription = ndk.subscribe(filter: filter)

        for await event in subscription.events {
            if let status = ProjectStatus.from(event: event) {
                // Only keep if newer than existing
                if let existing = projectStatuses[status.projectCoordinate] {
                    guard status.createdAt > existing.createdAt else {
                        continue
                    }
                }
                projectStatuses[status.projectCoordinate] = status
            }
        }
    }

    private func subscribeToNudges() async {
        isLoadingNudges = true
        defer { isLoadingNudges = false }

        let filter = NDKFilter(kinds: [4201], limit: 100)
        let subscription = ndk.subscribe(filter: filter)
        var nudgesByID: [String: Nudge] = [:]

        for await event in subscription.events {
            if let nudge = Nudge.from(event: event) {
                nudgesByID[nudge.id] = nudge
                nudges = Array(nudgesByID.values).sorted { $0.createdAt > $1.createdAt }
            }
        }
    }
}
