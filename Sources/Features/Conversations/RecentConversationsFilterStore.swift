//
// RecentConversationsFilterStore.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation
import Observation

/// Store for persisting the "Only by me" filter for recent conversations
@MainActor
@Observable
public final class RecentConversationsFilterStore {
    // MARK: Lifecycle

    /// Initialize the filter store and load saved state from UserDefaults
    public init() {
        self.onlyByMe = UserDefaults.standard.bool(forKey: storageKey)
    }

    // MARK: Public

    /// Whether to show only conversations where the current user is the author of the root event
    public private(set) var onlyByMe: Bool = false

    /// Toggle the "Only by me" filter state
    public func toggleOnlyByMe() {
        self.onlyByMe.toggle()
        save()
    }

    /// Set the "Only by me" filter state explicitly
    /// - Parameter enabled: Whether the filter should be enabled
    public func setOnlyByMe(_ enabled: Bool) {
        self.onlyByMe = enabled
        save()
    }

    // MARK: Private

    private let storageKey = "recent-conversations-only-by-me"

    /// Save the current filter state to UserDefaults
    private func save() {
        UserDefaults.standard.set(self.onlyByMe, forKey: storageKey)
    }
}
