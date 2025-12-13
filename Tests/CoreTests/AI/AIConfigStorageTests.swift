//
// AIConfigStorageTests.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

@testable import TENEXCore
import Testing

// MARK: - TestError

enum TestError: Error {
    case setupFailed
}

// MARK: - AIConfigStorageTests

@MainActor
@Suite("AIConfigStorage Tests")
struct AIConfigStorageTests {
    // MARK: Lifecycle

    init() async throws {
        // Use a dedicated test suite for UserDefaults
        guard let defaults = UserDefaults(suiteName: "test-ai-config") else {
            throw TestError.setupFailed
        }
        userDefaults = defaults
        let chain = KeychainStorage(service: "com.tenex.test.ai")
        keychain = chain
        storage = UserDefaultsAIConfigStorage(keychain: chain, userDefaults: defaults)

        // Clean up before tests
        try storage?.clear()
        try keychain?.clearAll()
    }

    // MARK: Internal

    var keychain: KeychainStorage?
    var storage: UserDefaultsAIConfigStorage?
    var userDefaults: UserDefaults?

    @Test("Save and load configuration")
    func saveAndLoad() async throws {
        guard let storage else { throw TestError.setupFailed }

        let config = AIConfig(
            llmConfigs: [
                LLMConfig(name: "Test", provider: .openai, model: "gpt-4"),
            ],
            activeLLMConfigID: nil
        )

        try storage.save(config)
        let loaded = try storage.load()

        #expect(loaded != nil)
        #expect(loaded?.llmConfigs.count == 1)
        #expect(loaded?.llmConfigs.first?.name == "Test")
        #expect(loaded?.llmConfigs.first?.provider == .openai)
        #expect(loaded?.llmConfigs.first?.model == "gpt-4")
    }

    @Test("Load returns nil when no config exists")
    func loadWhenEmpty() async throws {
        guard let storage else { throw TestError.setupFailed }

        try storage.clear()
        let loaded = try storage.load()
        #expect(loaded == nil)
    }

    @Test("Save and load API key")
    func aPIKeySaveAndLoad() async throws {
        guard let storage else { throw TestError.setupFailed }
        let configID = "test-config-123"
        let apiKey = "sk-test-key-abc"

        try storage.saveAPIKey(apiKey, for: configID)
        let loaded = try storage.loadAPIKey(for: configID)

        #expect(loaded == apiKey)
    }

    @Test("Load API key returns nil when not found")
    func loadAPIKeyWhenNotFound() async throws {
        guard let storage else { throw TestError.setupFailed }

        let loaded = try storage.loadAPIKey(for: "nonexistent")
        #expect(loaded == nil)
    }

    @Test("Delete API key")
    func testDeleteAPIKey() async throws {
        guard let storage else { throw TestError.setupFailed }
        let configID = "test-config-456"
        let apiKey = "sk-test-key-def"

        try storage.saveAPIKey(apiKey, for: configID)
        try storage.deleteAPIKey(for: configID)
        let loaded = try storage.loadAPIKey(for: configID)

        #expect(loaded == nil)
    }

    @Test("Clear removes all configuration")
    func testClear() async throws {
        guard let storage else { throw TestError.setupFailed }

        let config = AIConfig(
            llmConfigs: [LLMConfig(name: "Test", provider: .openai, model: "gpt-4")]
        )

        try storage.save(config)
        try storage.clear()
        let loaded = try storage.load()

        #expect(loaded == nil)
    }

    @Test("Save preserves all fields")
    func savePreservesAllFields() async throws {
        guard let storage else { throw TestError.setupFailed }

        let config = AIConfig(
            llmConfigs: [
                LLMConfig(name: "Fast", provider: .openai, model: "gpt-4o-mini"),
                LLMConfig(name: "Quality", provider: .anthropic, model: "claude-3-5-sonnet-20241022"),
            ],
            activeLLMConfigID: "test-id",
            featureAssignments: [.titleGeneration: "config-1", .summarization: "config-2"],
            ttsSettings: TTSSettings(
                enabled: true,
                voiceConfigs: [VoiceConfig(name: "Nova", provider: .openai, voiceID: "nova")],
                speed: 1.2,
                autoSpeak: true
            ),
            sttSettings: STTSettings(
                enabled: true,
                provider: .whisper,
                model: "whisper-1",
                fallbackChain: [.whisperKit]
            )
        )

        try storage.save(config)
        let loaded = try storage.load()

        #expect(loaded?.llmConfigs.count == 2)
        #expect(loaded?.activeLLMConfigID == "test-id")
        #expect(loaded?.featureAssignments[.titleGeneration] == "config-1")
        #expect(loaded?.ttsSettings.enabled == true)
        #expect(loaded?.ttsSettings.speed == 1.2)
        #expect(loaded?.sttSettings.provider == .whisper)
    }
}

// MARK: - InMemoryAIConfigStorageTests

@Suite("InMemoryAIConfigStorage Tests")
struct InMemoryAIConfigStorageTests {
    @Test("In-memory save and load")
    func inMemorySaveAndLoad() async throws {
        let storage = InMemoryAIConfigStorage()
        let config = AIConfig(
            llmConfigs: [LLMConfig(name: "Test", provider: .openai, model: "gpt-4")]
        )

        try storage.save(config)
        let loaded = try storage.load()

        #expect(loaded != nil)
        #expect(loaded?.llmConfigs.count == 1)
    }

    @Test("In-memory API key operations")
    func inMemoryAPIKeyOperations() async throws {
        let storage = InMemoryAIConfigStorage()
        let configID = "test-id"
        let apiKey = "sk-test"

        try storage.saveAPIKey(apiKey, for: configID)
        let loaded = try storage.loadAPIKey(for: configID)
        #expect(loaded == apiKey)

        try storage.deleteAPIKey(for: configID)
        let afterDelete = try storage.loadAPIKey(for: configID)
        #expect(afterDelete == nil)
    }

    @Test("In-memory clear")
    func inMemoryClear() async throws {
        let storage = InMemoryAIConfigStorage()
        let config = AIConfig()

        try storage.save(config)
        try storage.saveAPIKey("key", for: "id")
        try storage.clear()

        let loadedConfig = try storage.load()
        let loadedKey = try storage.loadAPIKey(for: "id")

        #expect(loadedConfig == nil)
        #expect(loadedKey == nil)
    }
}
