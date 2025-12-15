//
// InboxViewModel.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation
import Observation
import TENEXCore

/// Manages inbox message display and interactions
@MainActor
@Observable
public final class InboxViewModel {
    // MARK: Lifecycle

    /// Initialize with data store
    /// - Parameter dataStore: The data store providing inbox messages
    public init(dataStore: DataStore) {
        self.dataStore = dataStore
    }

    // MARK: Public

    // MARK: - Public Properties

    /// Inbox messages (already filtered and sorted by DataStore)
    public var inboxMessages: [Message] {
        self.dataStore.inboxMessages
    }

    /// Unread inbox count
    public var unreadCount: Int {
        self.dataStore.inboxUnreadCount
    }

    // MARK: - Public Methods

    /// Mark all inbox messages as read
    public func markAllRead() {
        self.dataStore.markInboxAsRead()
    }

    /// Check if a message is unread
    /// - Parameter message: The message to check
    /// - Returns: True if the message is unread
    public func isUnread(_ message: Message) -> Bool {
        message.createdAt > self.dataStore.lastInboxVisit
    }

    /// Get agent name from project statuses
    /// - Parameter pubkey: The agent's pubkey
    /// - Returns: The agent's name if found
    public func agentName(for pubkey: String) -> String? {
        for status in self.dataStore.projectStatuses.values {
            if let agent = status.agents.first(where: { $0.pubkey == pubkey }) {
                return agent.name
            }
        }
        return nil
    }

    // MARK: Private

    // MARK: - Dependencies

    private let dataStore: DataStore
}
