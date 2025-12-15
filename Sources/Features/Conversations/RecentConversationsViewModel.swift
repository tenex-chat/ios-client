//
// RecentConversationsViewModel.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation
import NDKSwiftCore
import os
import TENEXCore

/// Manages recent conversation threads and message grouping
@MainActor
@Observable
public final class RecentConversationsViewModel {
    // MARK: Lifecycle

    /// Initialize with dependencies
    /// - Parameters:
    ///   - dataStore: The data store for accessing conversation data
    ///   - ndk: The NDK instance for fetching thread metadata
    public init(dataStore: DataStore, ndk: NDK) {
        self.dataStore = dataStore
        self.ndk = ndk
    }

    // MARK: Public

    /// Group messages by thread ID (extracted from 'E' tag)
    public var conversationsByThread: [String: [Message]] {
        Dictionary(grouping: self.dataStore.recentConversationReplies) { message in
            message.threadID
        }
    }

    /// Get sorted thread IDs (by latest activity)
    public var sortedThreadIDs: [String] {
        self.conversationsByThread.keys.sorted { threadID1, threadID2 in
            let latest1 = self.conversationsByThread[threadID1]?.max { $0.createdAt < $1.createdAt }
            let latest2 = self.conversationsByThread[threadID2]?.max { $0.createdAt < $1.createdAt }
            return (latest1?.createdAt ?? .distantPast) > (latest2?.createdAt ?? .distantPast)
        }
    }

    // MARK: - Public Methods

    /// Fetch thread metadata (kind:11 events) for display
    /// - Parameter id: The thread ID
    /// - Returns: The Thread object if found
    public func getThread(id: String) -> TENEXCore.Thread? {
        if let cached = threadCache[id] {
            return cached
        }

        // Trigger async fetch
        Task {
            await self.fetchThread(id: id)
        }

        return nil
    }

    /// Get thread event for navigation to ChatView
    /// - Parameter id: The thread ID
    /// - Returns: The NDKEvent if found
    public func getThreadEvent(id: String) -> NDKEvent? {
        self.threadEventCache[id]
    }

    /// Get project for a thread based on the project coordinate
    /// - Parameter threadID: The thread ID
    /// - Returns: The Project if found
    public func getProject(for threadID: String) -> Project? {
        guard let messages = conversationsByThread[threadID],
              let firstMessage = messages.first,
              let projectCoordinate = firstMessage.projectCoordinate
        else {
            return nil
        }

        return self.dataStore.projects.first { $0.coordinate == projectCoordinate }
    }

    /// Get latest message for a thread
    /// - Parameter threadID: The thread ID
    /// - Returns: The most recent message in the thread
    public func latestMessage(for threadID: String) -> Message? {
        self.conversationsByThread[threadID]?.max { $0.createdAt < $1.createdAt }
    }

    // MARK: Private

    // MARK: - Dependencies

    private let dataStore: DataStore
    private let ndk: NDK
    private let logger = Logger(subsystem: "com.tenex.ios", category: "RecentConversations")

    // MARK: - State

    private var threadCache: [String: TENEXCore.Thread] = [:]
    private var threadEventCache: [String: NDKEvent] = [:]

    // MARK: - Private Methods

    private func fetchThread(id: String) async {
        self.logger.debug("Fetching thread: \(id)")

        let filter = NDKFilter(ids: [id], kinds: [11])
        let subscription = self.ndk.subscribe(filter: filter)

        var eventFound = false
        for await event in subscription.events.prefix(1) {
            eventFound = true

            // Cache the event first
            self.threadEventCache[id] = event

            // Then parse and cache the Thread
            if let thread = Thread.from(event: event) {
                self.threadCache[id] = thread
                self.logger.debug("Successfully cached thread: \(thread.title ?? id)")
            } else {
                self.logger.error("Failed to parse thread from event: \(id)")
            }

            // Apply cache size limits (keep last 100 threads)
            if self.threadEventCache.count > 100 {
                let keysToRemove = self.threadEventCache.keys.prefix(self.threadEventCache.count - 100)
                for key in keysToRemove {
                    self.threadEventCache.removeValue(forKey: key)
                    self.threadCache.removeValue(forKey: key)
                }
                self.logger.debug("Evicted \(keysToRemove.count) threads from cache")
            }
        }

        if !eventFound {
            self.logger.warning("Thread not found: \(id)")
        }
    }
}
