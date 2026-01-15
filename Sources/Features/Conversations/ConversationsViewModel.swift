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

    /// Get sorted thread IDs with all filters applied
    public var sortedThreadIDs: [String] {
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

        // Sort by latest activity (newest first)
        return timeFiltered.sorted { threadID1, threadID2 in
            let latest1 = latestMessage(for: threadID1)
            let latest2 = latestMessage(for: threadID2)
            return (latest1?.createdAt ?? .distantPast) > (latest2?.createdAt ?? .distantPast)
        }
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
        conversationsByThread[threadID]?.first?.projectCoordinate
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

    /// Get hierarchy info for a thread
    /// - Parameter threadID: The thread ID
    /// - Returns: Tuple of (depth, hasChildren, childCount)
    public func getHierarchyInfo(for threadID: String) -> (depth: Int, hasChildren: Bool, childCount: Int) {
        // Look up hierarchy info from conversation stores
        guard let projectCoordinate = getProjectCoordinate(for: threadID),
              let store = dataStore.conversationStore(for: projectCoordinate)
        else {
            return (0, false, 0)
        }

        // Find the hierarchical thread in the store's state
        if let hierarchicalThread = store.state.hierarchicalThreads.first(where: { $0.id == threadID }) {
            return (hierarchicalThread.depth, hierarchicalThread.hasChildren, hierarchicalThread.childCount)
        }

        // Fallback: check if this thread has children in the parent-to-children map
        let children = store.state.parentToChildren[threadID] ?? []
        return (0, !children.isEmpty, children.count)
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
