//
// LRUCache.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation

/// A thread-safe Least Recently Used (LRU) cache with automatic eviction
/// - Note: This cache evicts the oldest items when the maximum size is exceeded
@MainActor
public final class LRUCache<Key: Hashable, Value> {
    // MARK: Lifecycle

    /// Initialize a new LRU cache
    /// - Parameter maxSize: The maximum number of items to cache (default: 100)
    public init(maxSize: Int = 100) {
        self.maxSize = maxSize
    }

    // MARK: Public

    /// The number of items currently in the cache
    public var count: Int {
        cache.count
    }

    /// Whether the cache is empty
    public var isEmpty: Bool {
        cache.isEmpty
    }

    /// Get a value from the cache
    /// - Parameter key: The key to look up
    /// - Returns: The cached value, or nil if not found
    public func get(_ key: Key) -> Value? {
        guard let value = cache[key] else {
            return nil
        }

        // Update access order by moving to end
        accessOrder.removeAll { $0 == key }
        accessOrder.append(key)

        return value
    }

    /// Set a value in the cache
    /// - Parameters:
    ///   - key: The key to store
    ///   - value: The value to cache
    public func set(_ key: Key, _ value: Value) {
        // Remove existing entry from access order if updating
        if cache[key] != nil {
            accessOrder.removeAll { $0 == key }
        }

        cache[key] = value
        accessOrder.append(key)

        // Evict oldest entries if over capacity
        evictIfNeeded()
    }

    /// Check if the cache contains a key
    /// - Parameter key: The key to check
    /// - Returns: True if the key exists in the cache
    public func contains(_ key: Key) -> Bool {
        cache[key] != nil
    }

    /// Remove a value from the cache
    /// - Parameter key: The key to remove
    /// - Returns: The removed value, or nil if not found
    @discardableResult
    public func remove(_ key: Key) -> Value? {
        accessOrder.removeAll { $0 == key }
        return cache.removeValue(forKey: key)
    }

    /// Remove all values from the cache
    public func clear() {
        cache.removeAll()
        accessOrder.removeAll()
    }

    /// Subscript access to the cache
    public subscript(key: Key) -> Value? {
        get { get(key) }
        set {
            if let value = newValue {
                set(key, value)
            } else {
                remove(key)
            }
        }
    }

    // MARK: Private

    private let maxSize: Int
    private var cache: [Key: Value] = [:]
    private var accessOrder: [Key] = []

    /// Evict the least recently used entries if the cache is over capacity
    private func evictIfNeeded() {
        while cache.count > maxSize, !accessOrder.isEmpty {
            let oldestKey = accessOrder.removeFirst()
            cache.removeValue(forKey: oldestKey)
        }
    }
}

// MARK: - Async Fetching Support

public extension LRUCache {
    /// Get a value from the cache, or fetch it if not present
    /// - Parameters:
    ///   - key: The key to look up
    ///   - fetch: An async closure to fetch the value if not cached
    /// - Returns: The cached or fetched value, or nil if fetch failed
    func getOrFetch(
        _ key: Key,
        fetch: () async -> Value?
    ) async -> Value? {
        if let cached = get(key) {
            return cached
        }

        if let value = await fetch() {
            set(key, value)
            return value
        }

        return nil
    }
}
