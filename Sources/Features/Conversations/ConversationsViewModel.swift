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

    // MARK: - Observable State (views observe these)

    /// Sorted thread IDs with filters applied - the main list for display
    public private(set) var sortedThreadIDs: [String] = []

    /// Messages grouped by thread ID
    public private(set) var conversationsByThread: [String: [Message]] = [:]

    /// Latest message per thread for O(1) lookup
    public private(set) var latestMessageByThread: [String: Message] = [:]

    // MARK: - Computed Properties (cheap, no caching needed)

    /// All available projects for filtering (excludes archived projects)
    public var availableProjects: [Project] {
        let archivedIDs = archiveStorage.archivedProjectIDs()
        return dataStore.projects.filter { !archivedIDs.contains($0.id) }
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

    // MARK: - Recomputation (call when data changes)

    /// Recompute all derived state from DataStore
    /// Call this from view's .task or when you know data has changed
    public func recompute() {
        let replies = dataStore.recentConversationReplies

        // Group by thread
        conversationsByThread = Dictionary(grouping: replies) { $0.threadID }

        // Pre-compute latest message per thread
        var latestByThread: [String: Message] = [:]
        for (threadID, messages) in conversationsByThread {
            latestByThread[threadID] = messages.max { $0.createdAt < $1.createdAt }
        }
        latestMessageByThread = latestByThread

        // Compute sorted thread IDs
        sortedThreadIDs = computeSortedThreadIDs()
    }

    // MARK: - Filter Methods

    /// Set the time filter
    /// - Parameter filter: The new time filter
    public func setTimeFilter(_ filter: TimeFilter) {
        filterStore.setTimeFilter(filter)
        recompute()
    }

    /// Check if a project is selected
    /// - Parameter coordinate: The project coordinate
    /// - Returns: True if the project is selected or no filter is active
    public func isProjectSelected(_ coordinate: String) -> Bool {
        filterStore.isProjectSelected(coordinate)
    }

    /// Toggle project selection
    /// - Parameter coordinate: The project coordinate to toggle
    public func toggleProject(_ coordinate: String) {
        filterStore.toggleProject(coordinate)
        recompute()
    }

    /// Clear project filter (show all)
    public func clearProjectFilter() {
        filterStore.clearProjectFilter()
        recompute()
    }

    /// Select only a specific project
    /// - Parameter coordinate: The project coordinate to select exclusively
    public func selectOnlyProject(_ coordinate: String) {
        filterStore.selectOnlyProject(coordinate)
        recompute()
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
        if let coordinate = conversationsByThread[threadID]?.first?.projectCoordinate {
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

    /// Get latest message for a thread
    /// - Parameter threadID: The thread ID
    /// - Returns: The most recent message in the thread
    public func latestMessage(for threadID: String) -> Message? {
        latestMessageByThread[threadID]
    }

    /// Get conversation metadata (kind 513) for a thread from DataStore
    /// - Parameter threadID: The thread ID
    /// - Returns: The ConversationMetadata if found
    public func getConversationMetadata(for threadID: String) -> ConversationMetadata? {
        dataStore.getConversationMetadata(for: threadID)
    }

    /// Get hierarchy info for a thread using global DataStore hierarchy
    /// - Parameter threadID: The thread ID
    /// - Returns: Tuple of (depth, hasChildren, childCount)
    public func getHierarchyInfo(for threadID: String) -> (depth: Int, hasChildren: Bool, childCount: Int) {
        let hasParent = dataStore.threadParentMap[threadID] != nil
        let depth = hasParent ? computeDepth(for: threadID) : 0
        let children = dataStore.threadChildrenMap[threadID] ?? []
        let childCount = countAllDescendants(for: threadID)
        return (depth, !children.isEmpty, childCount)
    }

    /// Fetch thread event if not cached
    /// - Parameter threadID: The thread ID to fetch
    public func fetchThreadEventIfNeeded(for threadID: String) {
        guard threadEventCache[threadID] == nil else {
            return
        }

        Task {
            let filter = NDKFilter(ids: [threadID], kinds: [1])
            let subscription = ndk.subscribe(filter: filter)
            for await events in subscription.events.prefix(1) {
                if let event = events.first {
                    threadEventCache[threadID] = event
                }
            }
        }
    }

    // MARK: - Private

    private let dataStore: DataStore
    private let ndk: NDK
    private let filterStore: ConversationsFilterStore
    private let archiveStorage: ArchiveStorage
    private let logger = Logger(subsystem: "com.tenex.ios", category: "ConversationsViewModel")

    @ObservationIgnored
    private var threadEventCache: [String: NDKEvent] = [:]

    private func computeSortedThreadIDs() -> [String] {
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
            guard let latest = latestMessageByThread[threadID] else {
                return false
            }
            return latest.createdAt >= Date().addingTimeInterval(-threshold)
        }

        return orderByHierarchy(timeFiltered)
    }

    private func orderByHierarchy(_ threadIDs: [String]) -> [String] {
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

        // Pre-compute latest activity once
        let latestActivity: [String: Date] = threadIDs.reduce(into: [:]) { result, id in
            result[id] = latestMessageByThread[id]?.createdAt ?? .distantPast
        }

        let sortedRoots = rootThreads.sorted { id1, id2 in
            latestActivity[id1, default: .distantPast] > latestActivity[id2, default: .distantPast]
        }

        var result: [String] = []
        func addWithChildren(_ threadID: String) {
            result.append(threadID)
            if let children = parentToChildren[threadID] {
                let sortedChildren = children.sorted { id1, id2 in
                    latestActivity[id1, default: .distantPast] > latestActivity[id2, default: .distantPast]
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

    private func computeDepth(for threadID: String) -> Int {
        var depth = 0
        var currentID = threadID
        while let parentID = dataStore.threadParentMap[currentID] {
            depth += 1
            currentID = parentID
            if depth > 10 {
                break
            }
        }
        return depth
    }

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
}
