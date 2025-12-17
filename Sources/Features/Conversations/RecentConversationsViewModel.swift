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

    /// Get conversation metadata (kind 513) for a thread
    /// - Parameter threadID: The thread ID
    /// - Returns: The ConversationMetadata if found
    public func getConversationMetadata(for threadID: String) -> ConversationMetadata? {
        if let cached = conversationMetadataCache[threadID] {
            return cached
        }

        Task {
            await self.fetchConversationMetadata(for: threadID)
        }

        return nil
    }

    // MARK: Private

    // MARK: - Dependencies

    private let dataStore: DataStore
    private let ndk: NDK
    private let logger = Logger(subsystem: "com.tenex.ios", category: "RecentConversations")

    // MARK: - State

    private var threadCache: [String: TENEXCore.Thread] = [:]
    private var threadEventCache: [String: NDKEvent] = [:]
    private var conversationMetadataCache: [String: ConversationMetadata] = [:]

    // MARK: - Private Methods

    private func fetchThread(id: String) async {
        self.logger.debug("Fetching thread: \(id)")

        let filter = NDKFilter(ids: [id], kinds: [11])
        let subscription = self.ndk.subscribe(filter: filter)

        var eventFound = false
        for await events in subscription.events.prefix(1) {
            guard let event = events.first else { continue }
            eventFound = true

            self.threadEventCache[id] = event

            if let thread = Thread.from(event: event) {
                self.threadCache[id] = thread
                self.logger.debug("Successfully cached thread: \(thread.title ?? id)")
            } else {
                self.logger.error("Failed to parse thread from event: \(id)")
            }

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

        await self.fetchConversationMetadata(for: id)
    }

    private func fetchConversationMetadata(for threadID: String) async {
        self.logger.debug("Fetching conversation metadata for thread: \(threadID)")

        let filter = ConversationMetadata.filter(for: threadID)
        let subscription = self.ndk.subscribe(filter: filter)

        var eventFound = false
        for await events in subscription.events.prefix(1) {
            guard let event = events.first else { continue }
            eventFound = true

            if let metadata = ConversationMetadata.from(event: event) {
                self.conversationMetadataCache[threadID] = metadata
                self.logger.debug("Successfully cached conversation metadata: \(metadata.title ?? "no title")")
            } else {
                self.logger.error("Failed to parse conversation metadata from event")
            }

            if self.conversationMetadataCache.count > 100 {
                let keysToRemove = self.conversationMetadataCache.keys.prefix(
                    self.conversationMetadataCache.count - 100
                )
                for key in keysToRemove {
                    self.conversationMetadataCache.removeValue(forKey: key)
                }
                self.logger.debug("Evicted \(keysToRemove.count) conversation metadata from cache")
            }
        }

        if !eventFound {
            self.logger.debug("No conversation metadata found for thread: \(threadID)")
        }
    }
}
