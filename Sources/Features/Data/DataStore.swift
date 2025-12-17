//
// DataStore.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation
import NDKSwiftCore
import Observation
import os
import TENEXCore

// MARK: - DataStore

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

    /// Recent conversation replies (kind:1111 with #K:11) across all projects
    public private(set) var recentConversationReplies: [Message] = []

    /// Inbox messages (agent escalations p-tagging current user)
    public private(set) var inboxMessages: [Message] = []

    /// Unread inbox count
    public private(set) var inboxUnreadCount = 0

    /// Active operations: eventId -> Set of agent pubkeys currently working
    public private(set) var activeOperations: [String: Set<String>] = [:]

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
            self.logger.debug("Subscriptions already active for user: \(userPubkey)")
            return
        }

        self.logger.info("Starting subscriptions for user: \(userPubkey)")

        // Clean up existing subscriptions
        self.stopSubscriptions()

        self.userPubkey = userPubkey

        // Start new subscriptions
        self.projectsTask = Task { await self.subscribeToProjects(userPubkey: userPubkey) }
        self.agentsTask = Task { await self.subscribeToAgents() }
        self.toolsTask = Task { await self.subscribeToTools() }
        self.statusTask = Task { await self.subscribeToProjectStatuses(userPubkey: userPubkey) }
        self.nudgesTask = Task { await self.subscribeToNudges() }
        self.recentConversationsTask = Task { await self.subscribeToRecentConversations() }
        self.inboxTask = Task { await self.subscribeToInbox(userPubkey: userPubkey) }
        self.operationsTask = Task { await self.subscribeToOperationsStatus(userPubkey: userPubkey) }

        self.logger.info("All subscriptions started")
    }

    /// Stop all subscriptions and clear state
    public func stopSubscriptions() {
        self.logger.info("Stopping all subscriptions")

        self.projectsTask?.cancel()
        self.agentsTask?.cancel()
        self.toolsTask?.cancel()
        self.statusTask?.cancel()
        self.nudgesTask?.cancel()
        self.recentConversationsTask?.cancel()
        self.inboxTask?.cancel()
        self.operationsTask?.cancel()

        self.projectsTask = nil
        self.agentsTask = nil
        self.toolsTask = nil
        self.statusTask = nil
        self.nudgesTask = nil
        self.recentConversationsTask = nil
        self.inboxTask = nil
        self.operationsTask = nil

        // Clear state
        self.projects = []
        self.agents = []
        self.tools = []
        self.projectStatuses = [:]
        self.nudges = []
        self.recentConversationReplies = []
        self.inboxMessages = []
        self.inboxUnreadCount = 0
        self.activeOperations = [:]
        self.userPubkey = nil

        self.logger.info("All subscriptions stopped and state cleared")
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
        self.projectStatuses[projectCoordinate]
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
        try await self.ndk.publish(event)
    }

    // MARK: - Inbox Actions

    /// Mark all inbox messages as read
    public func markInboxAsRead() {
        self.lastInboxVisit = Date()
        self.inboxUnreadCount = 0
    }

    // MARK: Internal

    // MARK: - UserDefaults Helpers

    var lastInboxVisit: Date {
        get {
            UserDefaults.standard.object(forKey: "lastInboxVisit") as? Date ?? Date()
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "lastInboxVisit")
        }
    }

    // MARK: - Testing Support

    /// Set project status for testing purposes only
    /// - Parameters:
    ///   - status: The project status to set
    ///   - coordinate: The project coordinate
    func setProjectStatus(_ status: ProjectStatus, for coordinate: String) {
        self.projectStatuses[coordinate] = status
    }

    // MARK: Private

    // MARK: - Dependencies

    private let ndk: NDK
    private var userPubkey: String?
    private let logger = Logger(subsystem: "com.tenex.ios", category: "DataStore")

    // MARK: - Subscription Tasks

    private var projectsTask: Task<Void, Never>?
    private var agentsTask: Task<Void, Never>?
    private var toolsTask: Task<Void, Never>?
    private var statusTask: Task<Void, Never>?
    private var nudgesTask: Task<Void, Never>?
    private var recentConversationsTask: Task<Void, Never>?
    private var inboxTask: Task<Void, Never>?
    private var operationsTask: Task<Void, Never>?
}

// MARK: - Subscription Methods

extension DataStore {
    private func subscribeToProjects(userPubkey: String) async {
        self.isLoadingProjects = true
        defer { isLoadingProjects = false }

        var projectsByID: [String: Project] = [:]
        var projectOrder: [String] = []

        let subscription = self.ndk.subscribe(filter: Project.filter(for: userPubkey))

        for await events in subscription.events {
            for event in events {
                if let project = Project.from(event: event) {
                    if projectsByID[project.id] == nil {
                        projectOrder.append(project.id)
                    }
                    projectsByID[project.id] = project
                    self.projects = projectOrder.compactMap { projectsByID[$0] }
                }
            }
        }
    }

    private func subscribeToAgents() async {
        self.isLoadingAgents = true
        defer { isLoadingAgents = false }

        let filter = NDKFilter(kinds: [4199], limit: 100)
        let subscription = self.ndk.subscribe(filter: filter)
        var agentsByID: [String: AgentDefinition] = [:]

        for await events in subscription.events {
            for event in events {
                if let agent = AgentDefinition.from(event: event) {
                    agentsByID[agent.id] = agent
                    self.agents = Array(agentsByID.values)
                }
            }
        }
    }

    private func subscribeToTools() async {
        self.isLoadingTools = true
        defer { isLoadingTools = false }

        let filter = NDKFilter(kinds: [4200], limit: 100)
        let subscription = self.ndk.subscribe(filter: filter)
        var toolsByID: [String: MCPTool] = [:]

        for await events in subscription.events {
            for event in events {
                if let tool = MCPTool.from(event: event) {
                    toolsByID[tool.id] = tool
                    self.tools = Array(toolsByID.values)
                }
            }
        }
    }

    private func subscribeToProjectStatuses(userPubkey: String) async {
        let filter = ProjectStatus.filter(for: userPubkey)
        let subscription = self.ndk.subscribe(filter: filter)

        for await events in subscription.events {
            for event in events {
                if let status = ProjectStatus.from(event: event) {
                    // Only keep if newer than existing
                    if let existing = projectStatuses[status.projectCoordinate] {
                        guard status.createdAt > existing.createdAt else {
                            continue
                        }
                    }
                    self.projectStatuses[status.projectCoordinate] = status
                }
            }
        }
    }

    private func subscribeToNudges() async {
        self.isLoadingNudges = true
        defer { isLoadingNudges = false }

        let filter = NDKFilter(kinds: [4201], limit: 100)
        let subscription = self.ndk.subscribe(filter: filter)
        var nudgesByID: [String: Nudge] = [:]

        for await events in subscription.events {
            for event in events {
                if let nudge = Nudge.from(event: event) {
                    nudgesByID[nudge.id] = nudge
                    self.nudges = Array(nudgesByID.values).sorted { $0.createdAt > $1.createdAt }
                }
            }
        }
    }

    private func subscribeToRecentConversations() async {
        var currentProjectCoordinates: [String] = []

        while !Task.isCancelled {
            // Get current project coordinates
            let projectCoordinates = self.projects.map(\.coordinate)

            // Skip if no projects yet
            guard !projectCoordinates.isEmpty else {
                try? await Task.sleep(for: .seconds(1))
                continue
            }

            // Only restart subscription if projects changed
            guard projectCoordinates != currentProjectCoordinates else {
                try? await Task.sleep(for: .seconds(1))
                continue
            }

            currentProjectCoordinates = projectCoordinates

            // Create filter for recent conversation replies
            let filter = NDKFilter(
                kinds: [1111], // GenericReply
                limit: 200,
                tags: [
                    "a": Set(projectCoordinates), // All our projects
                    "K": Set(["11"]), // Root event kind is 11 (threads)
                ]
            )

            let subscription = self.ndk.subscribe(filter: filter)
            var messagesByID: [String: Message] = [:]

            for await events in subscription.events {
                // Check if projects changed (break to restart subscription immediately)
                if self.projects.map(\.coordinate) != currentProjectCoordinates {
                    break
                }

                for event in events {
                    if let message = Message.from(event: event) {
                        messagesByID[message.id] = message
                        self.recentConversationReplies = Array(messagesByID.values)
                            .sorted { $0.createdAt > $1.createdAt }
                    }
                }
            }

            // No sleep here - restart immediately when projects change
        }
    }

    private func subscribeToInbox(userPubkey: String) async {
        var currentAgentPubkeys: Set<String> = []

        while !Task.isCancelled {
            // Get all agent pubkeys from project statuses
            let agentPubkeys = Set(
                projectStatuses.values.flatMap { status in
                    status.agents.map(\.pubkey)
                }
            )

            guard !agentPubkeys.isEmpty else {
                try? await Task.sleep(for: .seconds(1))
                continue
            }

            // Only restart subscription if agent set changed
            guard agentPubkeys != currentAgentPubkeys else {
                try? await Task.sleep(for: .seconds(1))
                continue
            }

            currentAgentPubkeys = agentPubkeys

            // Create filter for inbox messages
            let filter = NDKFilter(
                authors: Array(agentPubkeys),
                kinds: [1111],
                limit: 100,
                tags: ["p": Set([userPubkey])]
            )

            let subscription = self.ndk.subscribe(filter: filter)
            var messagesByID: [String: Message] = [:]

            for await events in subscription.events {
                // Check if agent set changed (break to restart subscription immediately)
                let currentAgents = Set(
                    projectStatuses.values.flatMap { status in
                        status.agents.map(\.pubkey)
                    }
                )
                if currentAgents != currentAgentPubkeys {
                    break
                }

                for event in events {
                    if let message = Message.from(event: event) {
                        // Apply smart filtering
                        if await self.shouldIncludeInInbox(event: event, userPubkey: userPubkey) {
                            messagesByID[message.id] = message

                            // Sort: ask-tagged first, then by timestamp
                            self.inboxMessages = Array(messagesByID.values).sorted { msg1, msg2 in
                                if msg1.hasAskTag != msg2.hasAskTag {
                                    return msg1.hasAskTag
                                }
                                return msg1.createdAt > msg2.createdAt
                            }

                            // Update unread count
                            self.inboxUnreadCount = self.inboxMessages.count { $0.createdAt > self.lastInboxVisit }
                        }
                    }
                }
            }

            // No sleep here - restart immediately when agent set changes
        }
    }

    private func shouldIncludeInInbox(event: NDKEvent, userPubkey: String) async -> Bool {
        guard let eTag = event.tagValue("e"), !eTag.isEmpty else {
            self.logger.debug("No e-tag found, including in inbox: \(event.id)")
            return true
        }

        // Use NDK's fetchEvent with automatic cache-first behavior
        let fetched = self.ndk.fetchEvent(eTag)

        // Wait for event with timeout (cache hits return immediately)
        guard let replyToEvent = await self.waitForEvent(fetched, timeout: 5.0) else {
            self.logger.warning("Reply-to event not found, including in inbox: \(eTag)")
            return true
        }

        // If not replying to user's own message, include it
        guard replyToEvent.pubkey == userPubkey else {
            self.logger.debug("Not a reply to user's message, including in inbox")
            return true
        }

        // Check if the user's message is older than 5 minutes
        let now = Date()
        let fiveMinutesAgo = now.addingTimeInterval(-5 * 60)
        let replyToDate = Date(timeIntervalSince1970: TimeInterval(replyToEvent.createdAt))
        let timeSinceUserMessage = now.timeIntervalSince(replyToDate)
        let shouldInclude = replyToDate < fiveMinutesAgo

        self.logger.info("""
        Inbox filtering decision:
        - User message time: \(replyToDate)
        - Current time: \(now)
        - Time since user message: \(Int(timeSinceUserMessage))s
        - 5 minute threshold: \(fiveMinutesAgo)
        - Should include: \(shouldInclude)
        - Agent message ID: \(event.id)
        """)

        return shouldInclude
    }

    /// Helper to wait for fetchEvent to complete with timeout
    /// Returns immediately if event is already cached
    private func waitForEvent(_ fetched: NDKFetchedEvent, timeout: TimeInterval) async -> NDKEvent? {
        // If event is already available (cache hit), return immediately
        if let event = fetched.event {
            return event
        }

        // Wait for event to load or timeout
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if let event = fetched.event {
                return event
            }
            if !fetched.isLoading {
                // Loading completed but no event found
                return nil
            }
            try? await Task.sleep(for: .milliseconds(100))
        }

        return fetched.event
    }

    private func subscribeToOperationsStatus(userPubkey: String) async {
        // Subscribe to kind 24133 events where the user is tagged with uppercase P
        let filter = NDKFilter(
            kinds: [24_133],
            tags: ["P": Set([userPubkey])]
        )

        let subscription = self.ndk.subscribe(filter: filter)

        for await events in subscription.events {
            for event in events {
                self.handleOperationsStatus(event)
            }
        }
    }

    private func handleOperationsStatus(_ event: NDKEvent) {
        // Get the event ID this operation status is about
        guard let eventId = event.tagValue("e") else {
            return
        }

        // Collect all agent pubkeys from p tags (lowercase)
        let agentPubkeys = Set(
            event.tags(withName: "p").compactMap { tag -> String? in
                guard tag.count > 1 else {
                    return nil
                }
                return tag[1]
            }
        )

        // Update the active operations map
        // Empty set means no agents are working (clears the UI)
        self.activeOperations[eventId] = agentPubkeys

        self.logger.debug("Operations status updated for event \(eventId): \(agentPubkeys.count) agents")
    }
}
