//
// DataStore.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation
import NDKSwiftCore
import Observation

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

    /// Whether projects are currently loading
    public private(set) var isLoadingProjects = false

    /// Whether agents are currently loading
    public private(set) var isLoadingAgents = false

    /// Whether tools are currently loading
    public private(set) var isLoadingTools = false

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
    }

    /// Stop all subscriptions and clear state
    public func stopSubscriptions() {
        projectsTask?.cancel()
        agentsTask?.cancel()
        toolsTask?.cancel()
        statusTasks.values.forEach { $0.cancel() }

        projectsTask = nil
        agentsTask = nil
        toolsTask = nil
        statusTasks.removeAll()

        // Clear state
        projects = []
        agents = []
        tools = []
        projectStatuses = [:]
        userPubkey = nil
    }

    // MARK: - Project Status

    /// Subscribe to status updates for a specific project
    /// - Parameter projectID: The project identifier
    public func subscribeToProjectStatus(projectID: String) {
        guard statusTasks[projectID] == nil else {
            return
        }

        statusTasks[projectID] = Task {
            await subscribeToStatus(for: projectID)
        }
    }

    // MARK: Private

    // MARK: - Dependencies

    private let ndk: NDK
    private var userPubkey: String?

    // MARK: - Subscription Tasks

    private var projectsTask: Task<Void, Never>?
    private var agentsTask: Task<Void, Never>?
    private var toolsTask: Task<Void, Never>?
    private var statusTasks: [String: Task<Void, Never>] = [:]

    // MARK: - Private Subscription Methods

    private func subscribeToProjects(userPubkey: String) async {
        isLoadingProjects = true
        defer { isLoadingProjects = false }

        do {
            let filter = Project.filter(for: userPubkey)
            var projectsByID: [String: Project] = [:]
            var projectOrder: [String] = []

            let subscription = ndk.subscribeToEvents(filters: [filter])

            for try await event in subscription {
                if let project = Project.from(event: event) {
                    if projectsByID[project.id] == nil {
                        projectOrder.append(project.id)
                    }
                    projectsByID[project.id] = project
                    projects = projectOrder.compactMap { projectsByID[$0] }
                }
            }
        } catch {
            // Subscription cancelled or failed
            isLoadingProjects = false
        }
    }

    private func subscribeToAgents() async {
        isLoadingAgents = true
        defer { isLoadingAgents = false }

        do {
            let filter = NDKFilter(kinds: [4199], limit: 100)
            let subscription = ndk.subscribeToEvents(filters: [filter])
            var agentsByID: [String: AgentDefinition] = [:]

            for try await event in subscription {
                if let agent = AgentDefinition.from(event: event) {
                    agentsByID[agent.id] = agent
                    agents = Array(agentsByID.values)
                }
            }
        } catch {
            // Subscription cancelled or failed
            isLoadingAgents = false
        }
    }

    private func subscribeToTools() async {
        isLoadingTools = true
        defer { isLoadingTools = false }

        do {
            let filter = NDKFilter(kinds: [4200], limit: 100)
            let subscription = ndk.subscribeToEvents(filters: [filter])
            var toolsByID: [String: MCPTool] = [:]

            for try await event in subscription {
                if let tool = MCPTool.from(event: event) {
                    toolsByID[tool.id] = tool
                    tools = Array(toolsByID.values)
                }
            }
        } catch {
            // Subscription cancelled or failed
            isLoadingTools = false
        }
    }

    private func subscribeToStatus(for projectID: String) async {
        do {
            let filter = ProjectStatus.filter(for: projectID)
            let subscription = ndk.subscribeToEvents(filters: [filter])

            for try await event in subscription {
                if let status = ProjectStatus.from(event: event) {
                    projectStatuses[projectID] = status
                }
            }
        } catch {
            // Subscription cancelled or failed
        }
    }
}
