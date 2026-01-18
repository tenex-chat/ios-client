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

    /// Group messages by thread ID - cached to avoid O(n) recomputation on every access
    public var conversationsByThread: [String: [Message]] {
        rebuildCacheIfNeeded()
        return cachedConversationsByThread
    }

    /// Get sorted thread IDs with all filters applied, preserving hierarchy when available
    public var sortedThreadIDs: [String] {
        rebuildCacheIfNeeded()

        // Check if we need to rebuild sorted IDs (filter or hierarchy changed)
        let currentFilterVersion = filterStore.hasProjectFilter ? filterStore.selectedProjectCount : -1
        let currentTimeFilter = filterStore.timeFilter
        let currentHierarchyVersion = dataStore.threadParentMap.count

        if cachedSortedThreadIDs == nil ||
            lastFilterVersion != currentFilterVersion ||
            lastTimeFilter != currentTimeFilter ||
            lastHierarchyVersion != currentHierarchyVersion {
            rebuildSortedThreadIDs()
            lastFilterVersion = currentFilterVersion
            lastTimeFilter = currentTimeFilter
            lastHierarchyVersion = currentHierarchyVersion
        }

        return cachedSortedThreadIDs ?? []
    }

    // MARK: - Cache Management

    private var cachedConversationsByThread: [String: [Message]] = [:]
    private var cachedSortedThreadIDs: [String]?
    private var lastMessageCount: Int = -1
    private var lastFilterVersion: Int = -1
    private var lastTimeFilter: TimeFilter = .all
    private var lastHierarchyVersion: Int = -1

    private func rebuildCacheIfNeeded() {
        let currentMessages = dataStore.recentConversationReplies
        let currentCount = currentMessages.count

        // Only rebuild if message count changed (cheap check for data changes)
        guard currentCount != lastMessageCount else {
            return
        }

        cachedConversationsByThread = Dictionary(grouping: currentMessages) { $0.threadID }
        lastMessageCount = currentCount

        // Invalidate sorted thread IDs cache since underlying data changed
        cachedSortedThreadIDs = nil
    }

    private func rebuildSortedThreadIDs() {
        let allThreadIDs = Array(cachedConversationsByThread.keys)

        // Apply project filter
        let projectFiltered = allThreadIDs.filter { threadID in
            guard filterStore.hasProjectFilter else {
                return true
            }
            guard let projectCoordinate = getProjectCoordinateCached(for: threadID) else {
                return false
            }
            return filterStore.isProjectSelected(projectCoordinate)
        }

        // Apply time filter
        let timeFiltered = projectFiltered.filter { threadID in
            guard let threshold = filterStore.timeFilter.thresholdSeconds else {
                return true
            }
            guard let latestMsg = latestMessageCached(for: threadID) else {
                return false
            }
            let cutoff = Date().addingTimeInterval(-threshold)
            return latestMsg.createdAt >= cutoff
        }

        // Build hierarchical ordering
        cachedSortedThreadIDs = orderByHierarchyCached(timeFiltered)
    }

    // MARK: - Cached Helper Methods (use cache directly, no recomputation)

    /// Get latest message using cached data
    private func latestMessageCached(for threadID: String) -> Message? {
        cachedConversationsByThread[threadID]?.max { $0.createdAt < $1.createdAt }
    }

    /// Get project coordinate using cached data
    private func getProjectCoordinateCached(for threadID: String) -> String? {
        if let coordinate = cachedConversationsByThread[threadID]?.first?.projectCoordinate {
            return coordinate
        }
        for project in availableProjects {
            if let store = dataStore.conversationStore(for: project.coordinate),
               store.state.threadSummaries[threadID] != nil {
                return project.coordinate
            }
        }
        return nil
    }

    /// Order thread IDs using cached data
    private func orderByHierarchyCached(_ threadIDs: [String]) -> [String] {
        let globalParentMap = dataStore.threadParentMap
        let threadIDSet = Set(threadIDs)

        var childToParent: [String: String] = [:]
        var parentToChildren: [String: Set<String>] = [:]

        for threadID in threadIDs {
            if let parentID = globalParentMap[threadID], threadIDSet.contains(parentID) {
                childToParent[threadID] = parentID
                parentToChildren[parentID, default: []].insert(threadID)
            }
        }

        let rootThreads = threadIDs.filter { childToParent[$0] == nil }

        // Sort using cached data
        let sortedRoots = rootThreads.sorted { id1, id2 in
            let activity1 = latestMessageCached(for: id1)?.createdAt ?? .distantPast
            let activity2 = latestMessageCached(for: id2)?.createdAt ?? .distantPast
            return activity1 > activity2
        }

        var result: [String] = []
        func addWithChildren(_ threadID: String) {
            result.append(threadID)
            if let children = parentToChildren[threadID] {
                let sortedChildren = children.sorted { id1, id2 in
                    let activity1 = latestMessageCached(for: id1)?.createdAt ?? .distantPast
                    let activity2 = latestMessageCached(for: id2)?.createdAt ?? .distantPast
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

    // MARK: - Private Hierarchy Methods (kept for compatibility but now unused)

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
        rebuildCacheIfNeeded()
        return getProjectCoordinateCached(for: threadID)
    }

    /// Get latest message for a thread
    /// - Parameter threadID: The thread ID
    /// - Returns: The most recent message in the thread
    public func latestMessage(for threadID: String) -> Message? {
        rebuildCacheIfNeeded()
        return latestMessageCached(for: threadID)
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
