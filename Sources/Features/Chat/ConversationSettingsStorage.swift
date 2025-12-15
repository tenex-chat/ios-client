//
// ConversationSettingsStorage.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation

// MARK: - ConversationSettingsStorage

/// Protocol for storing conversation settings
public protocol ConversationSettingsStorage: Sendable {
    /// Load the conversation settings
    func load() -> ConversationSettings

    /// Save the conversation settings
    func save(_ settings: ConversationSettings)
}

// MARK: - UserDefaultsConversationSettingsStorage

/// Conversation settings storage backed by UserDefaults
public final class UserDefaultsConversationSettingsStorage: ConversationSettingsStorage, @unchecked Sendable {
    // MARK: Lifecycle

    public init(userDefaults: UserDefaults = .standard, key: String = "conversation_settings") {
        self.userDefaults = userDefaults
        self.key = key
    }

    // MARK: Public

    public func load() -> ConversationSettings {
        guard let data = userDefaults.data(forKey: key),
              let settings = try? JSONDecoder().decode(ConversationSettings.self, from: data)
        else {
            return ConversationSettings()
        }
        return settings
    }

    public func save(_ settings: ConversationSettings) {
        guard let data = try? JSONEncoder().encode(settings) else {
            return
        }
        self.userDefaults.set(data, forKey: self.key)
    }

    // MARK: Private

    private let userDefaults: UserDefaults
    private let key: String
}

// MARK: - InMemoryConversationSettingsStorage

/// In-memory conversation settings storage for testing
public final class InMemoryConversationSettingsStorage: ConversationSettingsStorage, @unchecked Sendable {
    // MARK: Lifecycle

    public init() {}

    // MARK: Public

    public func load() -> ConversationSettings {
        self.settings
    }

    public func save(_ settings: ConversationSettings) {
        self.settings = settings
    }

    // MARK: Private

    private var settings = ConversationSettings()
}
