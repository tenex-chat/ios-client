//
// ChatDraftStorage.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation

// MARK: - ChatDraftStorage

/// Protocol for storing chat message drafts
/// Drafts are stored locally to prevent users from losing their work
public protocol ChatDraftStorage: Sendable {
    /// Save a draft for a specific conversation
    /// - Parameters:
    ///   - draft: The draft to save
    /// - Throws: Error if the operation fails
    func saveDraft(_ draft: ChatDraft) async throws

    /// Load a draft for a specific conversation
    /// - Parameter conversationID: The conversation/thread ID
    /// - Returns: The saved draft, or nil if none exists
    /// - Throws: Error if the operation fails
    func loadDraft(for conversationID: String) async throws -> ChatDraft?

    /// Delete a draft for a specific conversation
    /// - Parameter conversationID: The conversation/thread ID
    /// - Throws: Error if the operation fails
    func deleteDraft(for conversationID: String) async throws

    /// Load all drafts
    /// - Returns: Dictionary of conversation IDs to drafts
    /// - Throws: Error if the operation fails
    func loadAllDrafts() async throws -> [String: ChatDraft]

    /// Clear all drafts
    /// - Throws: Error if the operation fails
    func clearAllDrafts() async throws
}

// MARK: - UserDefaultsChatDraftStorage

/// Chat draft storage backed by UserDefaults with actor-based thread safety
/// Uses an actor to serialize all read/write operations and prevent race conditions
public actor UserDefaultsChatDraftStorage: ChatDraftStorage {
    // MARK: Lifecycle

    /// Initialize storage with UserDefaults
    /// - Parameters:
    ///   - userDefaults: UserDefaults instance (defaults to .standard)
    ///   - key: Storage key (defaults to "chat_drafts")
    public init(userDefaults: UserDefaults = .standard, key: String = "chat_drafts") {
        self.userDefaults = userDefaults
        self.key = key
    }

    // MARK: Public

    public func saveDraft(_ draft: ChatDraft) async throws {
        var drafts = try await loadAllDrafts()
        drafts[draft.conversationID] = draft
        try await saveAllDrafts(drafts)
    }

    public func loadDraft(for conversationID: String) async throws -> ChatDraft? {
        let drafts = try await loadAllDrafts()
        return drafts[conversationID]
    }

    public func deleteDraft(for conversationID: String) async throws {
        var drafts = try await loadAllDrafts()
        drafts.removeValue(forKey: conversationID)
        try await saveAllDrafts(drafts)
    }

    public func loadAllDrafts() async throws -> [String: ChatDraft] {
        guard let data = userDefaults.data(forKey: key) else {
            return [:]
        }

        let decoder = JSONDecoder()
        return try decoder.decode([String: ChatDraft].self, from: data)
    }

    public func clearAllDrafts() async throws {
        userDefaults.removeObject(forKey: key)
    }

    // MARK: Private

    private let userDefaults: UserDefaults
    private let key: String

    private func saveAllDrafts(_ drafts: [String: ChatDraft]) async throws {
        let encoder = JSONEncoder()
        let data = try encoder.encode(drafts)
        userDefaults.set(data, forKey: key)
    }
}

// MARK: - InMemoryChatDraftStorage

/// In-memory chat draft storage for testing with actor-based thread safety
public actor InMemoryChatDraftStorage: ChatDraftStorage {
    // MARK: Lifecycle

    public init() {}

    // MARK: Public

    public func saveDraft(_ draft: ChatDraft) async throws {
        drafts[draft.conversationID] = draft
    }

    public func loadDraft(for conversationID: String) async throws -> ChatDraft? {
        drafts[conversationID]
    }

    public func deleteDraft(for conversationID: String) async throws {
        drafts.removeValue(forKey: conversationID)
    }

    public func loadAllDrafts() async throws -> [String: ChatDraft] {
        drafts
    }

    public func clearAllDrafts() async throws {
        drafts.removeAll()
    }

    // MARK: Private

    private var drafts: [String: ChatDraft] = [:]
}
