//
// MetadataFetcher.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation
import NDKSwiftCore
import os

/// A utility for fetching and caching Nostr event metadata
/// Reduces duplication across ViewModels that need to fetch thread events and conversation metadata
@MainActor
public final class MetadataFetcher {
    // MARK: Lifecycle

    /// Initialize a new metadata fetcher
    /// - Parameters:
    ///   - ndk: The NDK instance for fetching events
    ///   - cacheSize: Maximum number of items per cache (default: 100)
    public init(ndk: NDK, cacheSize: Int = 100) {
        self.ndk = ndk
        self.threadEventCache = LRUCache(maxSize: cacheSize)
        self.conversationMetadataCache = LRUCache(maxSize: cacheSize)
    }

    // MARK: Public

    /// Get a cached thread event
    /// - Parameter threadID: The thread ID
    /// - Returns: The NDKEvent if cached
    public func getThreadEvent(for threadID: String) -> NDKEvent? {
        threadEventCache.get(threadID)
    }

    /// Get cached conversation metadata
    /// - Parameter threadID: The thread ID
    /// - Returns: The ConversationMetadata if cached
    public func getConversationMetadata(for threadID: String) -> ConversationMetadata? {
        conversationMetadataCache.get(threadID)
    }

    /// Fetch a thread event if not cached
    /// - Parameter threadID: The thread ID to fetch
    /// - Returns: The NDKEvent if found
    public func fetchThreadEvent(for threadID: String) async -> NDKEvent? {
        // Return cached value if available
        if let cached = threadEventCache.get(threadID) {
            return cached
        }

        logger.debug("Fetching thread event: \(threadID)")

        let filter = NDKFilter(ids: [threadID], kinds: [11])
        let subscription = ndk.subscribe(filter: filter)

        for await events in subscription.events.prefix(1) {
            guard let event = events.first else {
                continue
            }
            threadEventCache.set(threadID, event)
            logger.debug("Cached thread event: \(threadID)")
            return event
        }

        logger.debug("Thread event not found: \(threadID)")
        return nil
    }

    /// Fetch conversation metadata if not cached
    /// - Parameter threadID: The thread ID to fetch metadata for
    /// - Returns: The ConversationMetadata if found
    public func fetchConversationMetadata(for threadID: String) async -> ConversationMetadata? {
        // Return cached value if available
        if let cached = conversationMetadataCache.get(threadID) {
            return cached
        }

        logger.debug("Fetching conversation metadata for thread: \(threadID)")

        let filter = ConversationMetadata.filter(for: threadID)
        let subscription = ndk.subscribe(filter: filter)

        for await events in subscription.events.prefix(1) {
            guard let event = events.first else {
                continue
            }

            if let metadata = ConversationMetadata.from(event: event) {
                conversationMetadataCache.set(threadID, metadata)
                logger.debug("Cached conversation metadata: \(metadata.title ?? "no title")")
                return metadata
            } else {
                logger.error("Failed to parse conversation metadata from event")
            }
        }

        logger.debug("No conversation metadata found for thread: \(threadID)")
        return nil
    }

    /// Prefetch thread event in background (fire and forget)
    /// - Parameter threadID: The thread ID to prefetch
    public func prefetchThreadEvent(for threadID: String) {
        guard !threadEventCache.contains(threadID) else {
            return
        }

        Task {
            _ = await fetchThreadEvent(for: threadID)
        }
    }

    /// Prefetch conversation metadata in background (fire and forget)
    /// - Parameter threadID: The thread ID to prefetch metadata for
    public func prefetchConversationMetadata(for threadID: String) {
        guard !conversationMetadataCache.contains(threadID) else {
            return
        }

        Task {
            _ = await fetchConversationMetadata(for: threadID)
        }
    }

    /// Clear all caches
    public func clearCaches() {
        threadEventCache.clear()
        conversationMetadataCache.clear()
    }

    // MARK: Private

    private let ndk: NDK
    private let logger = Logger(subsystem: "com.tenex.ios", category: "MetadataFetcher")
    private let threadEventCache: LRUCache<String, NDKEvent>
    private let conversationMetadataCache: LRUCache<String, ConversationMetadata>
}
