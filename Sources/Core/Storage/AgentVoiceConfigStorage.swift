//
// AgentVoiceConfigStorage.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation

// MARK: - AgentVoiceConfigStorage

/// Storage service for per-agent voice configurations
@Observable
public final class AgentVoiceConfigStorage: Sendable {
    // MARK: Lifecycle

    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        configs = Self.loadConfigs(from: userDefaults)
    }

    // MARK: Public

    /// Get all configured agent pubkeys
    public var configuredAgents: [String] {
        Array(configs.keys)
    }

    /// Get voice configuration for a specific agent
    public func config(for pubkey: String) -> AgentVoiceConfig? {
        configs[pubkey]
    }

    /// Set voice configuration for a specific agent
    public func setConfig(_ config: AgentVoiceConfig, for pubkey: String) {
        configs[pubkey] = config
        saveConfigs()
    }

    /// Remove voice configuration for a specific agent
    public func removeConfig(for pubkey: String) {
        configs.removeValue(forKey: pubkey)
        saveConfigs()
    }

    // MARK: Private

    private static let storageKey = "agent-voice-configs"

    private let userDefaults: UserDefaults
    private var configs: [String: AgentVoiceConfig]

    private static func loadConfigs(from userDefaults: UserDefaults) -> [String: AgentVoiceConfig] {
        guard let data = userDefaults.data(forKey: storageKey),
              let configs = try? JSONDecoder().decode([String: AgentVoiceConfig].self, from: data)
        else {
            return [:]
        }
        return configs
    }

    private func saveConfigs() {
        guard let data = try? JSONEncoder().encode(configs) else {
            return
        }
        userDefaults.set(data, forKey: Self.storageKey)
    }
}
