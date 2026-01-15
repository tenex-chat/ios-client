//
// ConversationsViewModel.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation
import NDKSwiftCore
import os
import TENEXCore

/// Manages the main Conversations tab with filtering by project and time
/// Uses DataStore as single source of truth for conversation metadata
@MainActor
@Observable
public final class ConversationsViewModel {
    // MARK: Lifecycle

    /// Initialize with dependencies
    /// - Parameters:
    ///   - dataStore: The data store (single source of truth for all data)
    ///   - ndk: The NDK instance for fetching thread events
    ///   - filterStore: The store for filter state persistence
    ///   - archiveStorage: Storage for archived project IDs
    public init(
        dataStore: DataStore,
        ndk: NDK,
        filterStore: ConversationsFilterStore,
        archiveStorage: ArchiveStorage = UserDefaultsArchiveStorage()
    ) {
        self.dataStore = dataStore
        self.ndk = ndk
        self.filterStore = filterStore
        self.archiveStorage = archiveStorage
    }

    // MARK: Public

    /// All available projects for filtering (excludes archived projects)
    public var availableProjects: [Project] {
        let archivedIDs = archiveStorage.archivedProjectIDs()
        return dataStore.projects.filter { !archivedIDs.contains($0.id) }
    }

    /// Group messages by thread ID (extracted from 'E' tag)
    public var conversationsByThread: [String: [Message]] {
        Dictionary(grouping: dataStore.recentConversationReplies) { message in
            message.threadID
        }
    }

    /// Get sorted thread IDs with all filters applied, preserving hierarchy when available
    public var sortedThreadIDs: [String] {
        // Get all thread IDs from messages (original working approach)
        let allThreadIDs = Array(conversationsByThread.keys)

        // Apply project filter
        let projectFiltered = allThreadIDs.filter { threadID in
            guard filterStore.hasProjectFilter else {
                return true
            }
            guard let projectCoordinate = getProjectCoordinate(for: threadID) else {
                return false
            }
            return filterStore.isProjectSelected(projectCoordinate)
        }

        // Apply time filter
        let timeFiltered = projectFiltered.filter { threadID in
            guard let threshold = filterStore.timeFilter.thresholdSeconds else {
                return true
            }
            guard let latestMessage = latestMessage(for: threadID) else {
                return false
            }
            let cutoff = Date().addingTimeInterval(-threshold)
            return latestMessage.createdAt >= cutoff
        }

        // Build hierarchical ordering if hierarchy info is available
        return orderByHierarchy(timeFiltered)
    }

    // MARK: - Private Hierarchy Methods

    /// Order thread IDs respecting parent-child hierarchy when available
    /// Parents appear before their children, with children nested immediately after
    private func orderByHierarchy(_ threadIDs: [String]) -> [String] {
        // Use global hierarchy from DataStore (observable, updates reactively)
        let globalParentMap = dataStore.threadParentMap
        let threadIDSet = Set(threadIDs)

        // Filter to only include relationships where both parent and child are in our list
        var childToParent: [String: String] = [:]
        var parentToChildren: [String: Set<String>] = [:]

        for threadID in threadIDs {
            if let parentID = globalParentMap[threadID], threadIDSet.contains(parentID) {
                childToParent[threadID] = parentID
                parentToChildren[parentID, default: []].insert(threadID)
            }
        }

        // Find root threads (those without parents in our filtered set)
        let rootThreads = threadIDs.filter { childToParent[$0] == nil }

        // Sort roots by latest activity
        let sortedRoots = rootThreads.sorted { id1, id2 in
            let activity1 = latestMessage(for: id1)?.createdAt ?? .distantPast
            let activity2 = latestMessage(for: id2)?.createdAt ?? .distantPast
            return activity1 > activity2
        }

        // Build final list with children nested under parents
        var result: [String] = []
        func addWithChildren(_ threadID: String) {
            result.append(threadID)
            if let children = parentToChildren[threadID] {
                let sortedChildren = children.sorted { id1, id2 in
                    let activity1 = latestMessage(for: id1)?.createdAt ?? .distantPast
                    let activity2 = latestMessage(for: id2)?.createdAt ?? .distantPast
                    return activity1 > activity2
                }
                for child in sortedChildren {
                    addWithChildren(child)
                }
            }
        }

        for root in sortedRoots {
            addWithChildren(root)
        }

        return result
    }

    /// Current time filter
    public var currentTimeFilter: TimeFilter {
        filterStore.timeFilter
    }

    /// Whether project filter is active
    public var hasProjectFilter: Bool {
        filterStore.hasProjectFilter
    }

    /// Number of selected projects
    public var selectedProjectCount: Int {
        filterStore.selectedProjectCount
    }

    // MARK: - Filter Methods

    /// Set the time filter
    public func setTimeFilter(_ filter: TimeFilter) {
        filterStore.setTimeFilter(filter)
    }

    /// Check if a project is selected
    public func isProjectSelected(_ coordinate: String) -> Bool {
        filterStore.isProjectSelected(coordinate)
    }

    /// Toggle project selection
    public func toggleProject(_ coordinate: String) {
        filterStore.toggleProject(coordinate)
    }

    /// Clear project filter (show all)
    public func clearProjectFilter() {
        filterStore.clearProjectFilter()
    }

    /// Select only a specific project
    public func selectOnlyProject(_ coordinate: String) {
        filterStore.selectOnlyProject(coordinate)
    }

    // MARK: - Data Access Methods

    /// Get thread event for navigation to ChatView
    /// - Parameter id: The thread ID
    /// - Returns: The NDKEvent if found
    public func getThreadEvent(id: String) -> NDKEvent? {
        threadEventCache[id]
    }

    /// Get project for a thread based on the project coordinate
    /// - Parameter threadID: The thread ID
    /// - Returns: The Project if found
    public func getProject(for threadID: String) -> Project? {
        guard let coordinate = getProjectCoordinate(for: threadID) else {
            return nil
        }
        return dataStore.projects.first { $0.coordinate == coordinate }
    }

    /// Get the project coordinate for a thread
    /// - Parameter threadID: The thread ID
    /// - Returns: The project coordinate if found
    public func getProjectCoordinate(for threadID: String) -> String? {
        // First check messages
        if let coordinate = conversationsByThread[threadID]?.first?.projectCoordinate {
            return coordinate
        }

        // Fallback: check thread summaries in project stores
        for project in availableProjects {
            if let store = dataStore.conversationStore(for: project.coordinate),
               store.state.threadSummaries[threadID] != nil {
                return project.coordinate
            }
        }

        return nil
    }

    /// Get latest message for a thread
    /// - Parameter threadID: The thread ID
    /// - Returns: The most recent message in the thread
    public func latestMessage(for threadID: String) -> Message? {
        conversationsByThread[threadID]?.max { $0.createdAt < $1.createdAt }
    }

    /// Get conversation metadata (kind 513) for a thread from DataStore
    /// - Parameter threadID: The thread ID
    /// - Returns: The ConversationMetadata if found
    public func getConversationMetadata(for threadID: String) -> ConversationMetadata? {
        // Read directly from DataStore - single source of truth
        dataStore.getConversationMetadata(for: threadID)
    }

    /// Get hierarchy info for a thread using global DataStore hierarchy
    /// - Parameter threadID: The thread ID
    /// - Returns: Tuple of (depth, hasChildren, childCount)
    public func getHierarchyInfo(for threadID: String) -> (depth: Int, hasChildren: Bool, childCount: Int) {
        // Use global hierarchy from DataStore (observable, updates reactively)
        let hasParent = dataStore.threadParentMap[threadID] != nil
        let depth = hasParent ? computeDepth(for: threadID) : 0
        let children = dataStore.threadChildrenMap[threadID] ?? []
        let childCount = countAllDescendants(for: threadID)

        return (depth, !children.isEmpty, childCount)
    }

    /// Compute depth by tracing parent chain using global DataStore hierarchy
    private func computeDepth(for threadID: String) -> Int {
        var depth = 0
        var currentID = threadID
        while let parentID = dataStore.threadParentMap[currentID] {
            depth += 1
            currentID = parentID
            // Prevent infinite loops
            if depth > 10 {
                break
            }
        }
        return depth
    }

    /// Count all descendants recursively using global DataStore hierarchy
    private func countAllDescendants(for threadID: String) -> Int {
        guard let children = dataStore.threadChildrenMap[threadID] else {
            return 0
        }
        var count = children.count
        for child in children {
            count += countAllDescendants(for: child)
        }
        return count
    }

    /// Fetch thread event if not cached
    /// - Parameter threadID: The thread ID to fetch
    public func fetchThreadEventIfNeeded(for threadID: String) {
        guard threadEventCache[threadID] == nil else {
            return
        }

        Task {
            logger.debug("Fetching thread event: \(threadID)")
            let filter = NDKFilter(ids: [threadID], kinds: [1])
            let subscription = ndk.subscribe(filter: filter)

            for await events in subscription.events.prefix(1) {
                if let event = events.first {
                    threadEventCache[threadID] = event
                    logger.debug("Cached thread event: \(threadID)")
                }
            }
        }
    }

    // MARK: Private

    private let dataStore: DataStore
    private let ndk: NDK
    private let filterStore: ConversationsFilterStore
    private let archiveStorage: ArchiveStorage
    private let logger = Logger(subsystem: "com.tenex.ios", category: "ConversationsViewModel")

    // Thread event cache for navigation (transient UI state, not global data)
    private var threadEventCache: [String: NDKEvent] = [:]
}
