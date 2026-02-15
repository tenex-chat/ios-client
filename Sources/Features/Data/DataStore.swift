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

    /// Recent conversation replies (kind:1 with e-tag) across all projects
    public private(set) var recentConversationReplies: [Message] = []

    /// Inbox messages (agent escalations p-tagging current user)
    public private(set) var inboxMessages: [Message] = []

    /// Unread inbox count
    public private(set) var inboxUnreadCount = 0

    /// Active operations: eventId -> Set of agent pubkeys currently working
    public private(set) var activeOperations: [String: Set<String>] = [:]

    /// Conversation metadata (kind:513) keyed by thread ID - SINGLE SOURCE OF TRUTH
    public private(set) var conversationMetadata: [String: ConversationMetadata] = [:]

    /// Thread hierarchy: child thread ID -> parent thread ID (from delegation tag)
    public private(set) var threadParentMap: [String: String] = [:]

    /// Thread hierarchy: parent thread ID -> child thread IDs
    public private(set) var threadChildrenMap: [String: Set<String>] = [:]

    /// Conversation stores keyed by project coordinate
    /// @ObservationIgnored to prevent infinite render loops when stores are created during view rendering
    @ObservationIgnored
    private var conversationStores: [String: ProjectConversationStore] = [:]

    /// Get or create a conversation store for a project
    /// - Parameter projectCoordinate: The project coordinate
    /// - Returns: The conversation store for the project
    public func conversationStore(for projectCoordinate: String) -> ProjectConversationStore? {
        if let store = conversationStores[projectCoordinate] {
            return store
        }
        let store = ProjectConversationStore(ndk: ndk, projectCoordinate: projectCoordinate)
        store.subscribe()
        conversationStores[projectCoordinate] = store
        return store
    }

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
        self.metadataTask = Task { await self.subscribeToConversationMetadata() }
        self.threadHierarchyTask = Task { await self.subscribeToThreadHierarchy() }

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
        self.metadataTask?.cancel()
        self.threadHierarchyTask?.cancel()

        self.projectsTask = nil
        self.agentsTask = nil
        self.toolsTask = nil
        self.statusTask = nil
        self.nudgesTask = nil
        self.recentConversationsTask = nil
        self.inboxTask = nil
        self.operationsTask = nil
        self.metadataTask = nil
        self.threadHierarchyTask = nil

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
        self.conversationMetadata = [:]
        self.threadParentMap = [:]
        self.threadChildrenMap = [:]
        self.conversationStores = [:]
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
            .build(signer: ndk.signer)
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
    private var metadataTask: Task<Void, Never>?
    private var threadHierarchyTask: Task<Void, Never>?
}

// MARK: - Conversation Metadata Access (Single Source of Truth)

public extension DataStore {
    /// Get conversation metadata for a thread ID
    /// - Parameter threadID: The thread ID
    /// - Returns: The ConversationMetadata if available
    func getConversationMetadata(for threadID: String) -> ConversationMetadata? {
        conversationMetadata[threadID]
    }

    /// Get all conversation metadata for a specific project
    /// - Parameter projectCoordinate: The project coordinate
    /// - Returns: Array of ConversationMetadata sorted by creation date (newest first)
    func getConversationMetadata(forProject projectCoordinate: String) -> [ConversationMetadata] {
        conversationMetadata.values
            .filter { $0.projectCoordinate == projectCoordinate }
            .sorted { $0.createdAt > $1.createdAt }
    }

    /// Get all conversation metadata sorted by creation date (newest first)
    var allConversationMetadata: [ConversationMetadata] {
        conversationMetadata.values.sorted { $0.createdAt > $1.createdAt }
    }
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
            var hasChanges = false
            for event in events {
                if let project = Project.from(event: event) {
                    if projectsByID[project.id] == nil {
                        projectOrder.append(project.id)
                        hasChanges = true
                    }
                    projectsByID[project.id] = project
                }
            }
            // Only update UI if there were changes
            if hasChanges {
                self.projects = projectOrder.compactMap { projectsByID[$0] }
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
            var hasChanges = false
            for event in events {
                if let agent = AgentDefinition.from(event: event) {
                    if agentsByID[agent.id] == nil {
                        hasChanges = true
                    }
                    agentsByID[agent.id] = agent
                }
            }
            // Only update UI if there were changes
            if hasChanges {
                self.agents = Array(agentsByID.values)
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
            var hasChanges = false
            for event in events {
                if let tool = MCPTool.from(event: event) {
                    if toolsByID[tool.id] == nil {
                        hasChanges = true
                    }
                    toolsByID[tool.id] = tool
                }
            }
            // Only update UI if there were changes
            if hasChanges {
                self.tools = Array(toolsByID.values)
            }
        }
    }

    private func subscribeToProjectStatuses(userPubkey: String) async {
        let filter = ProjectStatus.filter(for: userPubkey)
        let subscription = self.ndk.subscribe(filter: filter)

        // Track statuses locally, only update observable when batch has changes
        var localStatuses: [String: ProjectStatus] = [:]

        for await events in subscription.events {
            var hasChanges = false
            for event in events {
                if let status = ProjectStatus.from(event: event) {
                    // Only keep if newer than existing (check local copy)
                    if let existing = localStatuses[status.projectCoordinate] {
                        guard status.createdAt > existing.createdAt else {
                            continue
                        }
                    }
                    localStatuses[status.projectCoordinate] = status
                    hasChanges = true
                }
            }
            // Only update observable if there were actual changes
            if hasChanges {
                self.projectStatuses = localStatuses
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
            var hasNewNudges = false
            for event in events {
                if let nudge = Nudge.from(event: event) {
                    if nudgesByID[nudge.id] == nil {
                        nudgesByID[nudge.id] = nudge
                        hasNewNudges = true
                    }
                }
            }
            // Only update UI if there were actually new nudges
            if hasNewNudges {
                self.nudges = Array(nudgesByID.values).sorted { $0.createdAt > $1.createdAt }
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

            // Create filter for recent conversation messages
            let filter = NDKFilter(
                kinds: [1],
                limit: 200,
                tags: [
                    "a": Set(projectCoordinates), // All our projects
                ]
            )

            let subscription = self.ndk.subscribe(filter: filter)
            var messagesByID: [String: Message] = [:]

            for await events in subscription.events {
                // Check if projects changed (break to restart subscription immediately)
                if self.projects.map(\.coordinate) != currentProjectCoordinates {
                    break
                }

                var hasNewMessages = false
                for event in events {
                    if let message = Message.from(event: event) {
                        // Only count as new if not already present
                        if messagesByID[message.id] == nil {
                            messagesByID[message.id] = message
                            hasNewMessages = true
                        }
                    }
                }
                // Only update UI if there were actually new messages
                if hasNewMessages {
                    self.recentConversationReplies = Array(messagesByID.values)
                        .sorted { $0.createdAt > $1.createdAt }
                }
            }

            // No sleep here - restart immediately when projects change
        }
    }

    private func subscribeToInbox(userPubkey: String) async {
        var currentAgentPubkeys: Set<String> = []

        while !Task.isCancelled {
            let agentPubkeys = getAgentPubkeysFromStatuses()

            guard !agentPubkeys.isEmpty else {
                try? await Task.sleep(for: .seconds(1))
                continue
            }
            guard agentPubkeys != currentAgentPubkeys else {
                try? await Task.sleep(for: .seconds(1))
                continue
            }

            currentAgentPubkeys = agentPubkeys
            await runInboxSubscription(
                userPubkey: userPubkey,
                agentPubkeys: agentPubkeys,
                currentAgentPubkeys: currentAgentPubkeys
            )
        }
    }

    private func getAgentPubkeysFromStatuses() -> Set<String> {
        Set(projectStatuses.values.flatMap { $0.agents.map(\.pubkey) })
    }

    private func runInboxSubscription(
        userPubkey: String,
        agentPubkeys: Set<String>,
        currentAgentPubkeys: Set<String>
    ) async {
        let filter = NDKFilter(
            authors: Array(agentPubkeys),
            kinds: [1],
            limit: 100,
            tags: ["p": Set([userPubkey])]
        )

        let subscription = self.ndk.subscribe(filter: filter)
        var messagesByID: [String: Message] = [:]

        for await events in subscription.events {
            if getAgentPubkeysFromStatuses() != currentAgentPubkeys { break }

            var batchHasNewMessages = false
            for event in events {
                if let message = Message.from(event: event),
                   await self.shouldIncludeInInbox(event: event, userPubkey: userPubkey) {
                    messagesByID[message.id] = message
                    batchHasNewMessages = true
                }
            }

            if batchHasNewMessages {
                updateInboxUI(from: messagesByID)
            }
        }
    }

    private func updateInboxUI(from messagesByID: [String: Message]) {
        self.inboxMessages = Array(messagesByID.values).sorted { msg1, msg2 in
            if msg1.hasAskTag != msg2.hasAskTag {
                return msg1.hasAskTag
            }
            return msg1.createdAt > msg2.createdAt
        }
        self.inboxUnreadCount = self.inboxMessages.count { $0.createdAt > self.lastInboxVisit }
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

        // Track operations locally, only update observable when batch has changes
        var localOperations: [String: Set<String>] = [:]

        for await events in subscription.events {
            var hasChanges = false
            for event in events {
                if let (eventId, agentPubkeys, changed) = parseOperationsEvent(event, current: localOperations) {
                    if changed {
                        if agentPubkeys.isEmpty {
                            localOperations.removeValue(forKey: eventId)
                        } else {
                            localOperations[eventId] = agentPubkeys
                        }
                        hasChanges = true
                    }
                }
            }
            // Only update observable if there were actual changes
            if hasChanges {
                self.activeOperations = localOperations
            }
        }
    }

    private func parseOperationsEvent(
        _ event: NDKEvent,
        current: [String: Set<String>]
    ) -> (eventId: String, agents: Set<String>, changed: Bool)? {
        // Get the event ID this operation status is about
        guard let eventId = event.tagValue("e") else {
            return nil
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

        // Check if this is actually a change from current state
        let currentAgents = current[eventId]
        let isChange: Bool
        if agentPubkeys.isEmpty {
            isChange = currentAgents != nil
        } else {
            isChange = currentAgents != agentPubkeys
        }

        return (eventId, agentPubkeys, isChange)
    }

    /// Subscribe to conversation metadata (kind:513) for all projects
    /// This is the SINGLE SOURCE OF TRUTH for conversation metadata
    private func subscribeToConversationMetadata() async {
        var currentProjectCoordinates: [String] = []
        var localMetadata: [String: ConversationMetadata] = [:]

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
            localMetadata = [:] // Reset local cache when projects change
            self.logger.info("Starting conversation metadata subscription for \(projectCoordinates.count) projects")

            // Subscribe to kind:513 for all our projects
            let filter = NDKFilter(
                kinds: [513],
                tags: ["a": Set(projectCoordinates)]
            )

            let subscription = self.ndk.subscribe(filter: filter)

            for await events in subscription.events {
                // Check if projects changed (break to restart subscription immediately)
                if self.projects.map(\.coordinate) != currentProjectCoordinates {
                    break
                }

                var hasChanges = false
                for event in events {
                    if let metadata = ConversationMetadata.from(event: event) {
                        // Only update if newer than existing
                        if let existing = localMetadata[metadata.threadID] {
                            guard metadata.createdAt > existing.createdAt else {
                                continue
                            }
                        }
                        localMetadata[metadata.threadID] = metadata
                        hasChanges = true
                        self.logger.debug("Updated metadata for thread: \(metadata.threadID)")
                    }
                }
                // Only update observable if there were actual changes
                if hasChanges {
                    self.conversationMetadata = localMetadata
                }
            }
        }
    }

    /// Subscribe to thread events (kind:1 with title tag) to build hierarchy from delegation tags
    /// This provides global parent-child tracking independent of per-project stores
    private func subscribeToThreadHierarchy() async {
        var currentProjectCoordinates: [String] = []
        var localParentMap: [String: String] = [:]
        var localChildrenMap: [String: Set<String>] = [:]

        while !Task.isCancelled {
            let projectCoordinates = self.projects.map(\.coordinate)

            guard !projectCoordinates.isEmpty else {
                try? await Task.sleep(for: .seconds(1))
                continue
            }

            guard projectCoordinates != currentProjectCoordinates else {
                try? await Task.sleep(for: .seconds(1))
                continue
            }

            currentProjectCoordinates = projectCoordinates
            localParentMap = [:] // Reset when projects change
            localChildrenMap = [:]
            self.logger.info("Starting thread hierarchy subscription for \(projectCoordinates.count) projects")

            let filter = NDKFilter(kinds: [1], limit: 500, tags: ["a": Set(projectCoordinates)])
            let subscription = self.ndk.subscribe(filter: filter)

            for await events in subscription.events {
                if self.projects.map(\.coordinate) != currentProjectCoordinates { break }
                let changed = processThreadHierarchyEvents(
                    events,
                    parentMap: &localParentMap,
                    childrenMap: &localChildrenMap
                )
                if changed {
                    self.threadParentMap = localParentMap
                    self.threadChildrenMap = localChildrenMap
                }
            }
        }
    }

    /// Process thread events to extract delegation hierarchy
    /// - Returns: true if hierarchy was changed
    private func processThreadHierarchyEvents(
        _ events: [NDKEvent],
        parentMap: inout [String: String],
        childrenMap: inout [String: Set<String>]
    ) -> Bool {
        var hierarchyChanged = false
        var threadCount = 0

        for event in events {
            guard event.tags(withName: "e").isEmpty,
                  let titleTag = event.tags(withName: "title").first,
                  titleTag.count > 1 else { continue }

            threadCount += 1

            if let delegationTag = event.tags(withName: "delegation").first,
               delegationTag.count > 1 {
                let parentID = delegationTag[1]
                if !parentID.isEmpty, parentMap[event.id] != parentID {
                    parentMap[event.id] = parentID
                    childrenMap[parentID, default: []].insert(event.id)
                    hierarchyChanged = true
                    self.logger.info("Found delegation: Thread \(event.id.prefix(8)) -> parent \(parentID.prefix(8))")
                }
            }
        }

        // Capture counts before logging to avoid autoclosure capturing inout parameters
        let parentCount = parentMap.count

        if threadCount > 0 {
            self.logger.info("Processed \(threadCount) thread events, \(parentCount) with delegation tags")
        }

        if hierarchyChanged {
            self.logger.info("Thread hierarchy updated: \(parentCount) child threads")
        }

        return hierarchyChanged
    }
}
