//
// AISettingsViewModelTests.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

@testable import TENEXCore
@testable import TENEXFeatures
import Testing

// MARK: - AISettingsViewModelTests

@MainActor
@Suite("AISettingsViewModel Tests")
struct AISettingsViewModelTests {
    // MARK: Lifecycle

    init() async throws {
        storage = InMemoryAIConfigStorage()
        capabilityDetector = MockAICapabilityDetector(
            appleIntelligenceAvailable: true,
            speechTranscriberAvailable: true,
            whisperKitAvailable: true
        )
        viewModel = AISettingsViewModel(
            storage: storage,
            capabilityDetector: capabilityDetector
        )
    }

    // MARK: Internal

    let storage: InMemoryAIConfigStorage
    let capabilityDetector: MockAICapabilityDetector
    let viewModel: AISettingsViewModel

    // MARK: - Load/Save Tests

    @Test("Load configuration from storage")
    func loadConfiguration() async throws {
        // Setup
        let config = AIConfig(
            llmConfigs: [
                LLMConfig(name: "Test", provider: .openai, model: "gpt-4"),
            ]
        )
        try storage.save(config)

        // Load
        await viewModel.load()

        // Verify
        #expect(viewModel.config.llmConfigs.count == 1)
        #expect(viewModel.config.llmConfigs.first?.name == "Test")
        #expect(!viewModel.hasUnsavedChanges)
    }

    @Test("Load returns default when no config exists")
    func loadWhenEmpty() async throws {
        await viewModel.load()
        #expect(viewModel.config.llmConfigs.isEmpty)
        #expect(!viewModel.hasUnsavedChanges)
    }

    @Test("Save configuration to storage")
    func saveConfiguration() async throws {
        // Setup
        viewModel.config = AIConfig(
            llmConfigs: [
                LLMConfig(name: "Test", provider: .anthropic, model: "claude-3-5-sonnet-20241022"),
            ]
        )

        // Save
        try await viewModel.save()

        // Verify
        let loaded = try storage.load()
        #expect(loaded != nil)
        #expect(loaded?.llmConfigs.count == 1)
        #expect(!viewModel.hasUnsavedChanges)
    }

    @Test("Detect unsaved changes")
    func detectUnsavedChanges() async throws {
        // Load initial config
        let config = AIConfig(llmConfigs: [])
        try storage.save(config)
        await viewModel.load()
        #expect(!viewModel.hasUnsavedChanges)

        // Make a change
        viewModel.config.llmConfigs.append(
            LLMConfig(name: "New", provider: .openai, model: "gpt-4")
        )

        // Verify unsaved changes detected
        #expect(viewModel.hasUnsavedChanges)
    }

    @Test("TTS settings changes are detected and persisted")
    func ttsSettingsChangesArePersisted() async throws {
        // Load initial default config
        await viewModel.load()
        #expect(!viewModel.hasUnsavedChanges)

        // Get initial TTS provider
        let initialProvider = viewModel.config.ttsSettings.provider

        // Change TTS settings (simulating user interaction)
        viewModel.config.ttsSettings.enabled = true
        viewModel.config.ttsSettings.provider = .openai
        viewModel.config.ttsSettings.speed = 1.5

        // Verify unsaved changes are detected
        #expect(viewModel.hasUnsavedChanges, "TTS settings changes should be detected")

        // Save
        try await viewModel.save()
        #expect(!viewModel.hasUnsavedChanges)

        // Create new ViewModel (simulating navigation back to settings)
        let newViewModel = AISettingsViewModel(storage: storage, capabilityDetector: capabilityDetector)
        await newViewModel.load()

        // Verify TTS settings persisted
        #expect(newViewModel.config.ttsSettings.enabled == true)
        #expect(newViewModel.config.ttsSettings.provider == .openai)
        #expect(newViewModel.config.ttsSettings.speed == 1.5)
    }

    @Test("STT settings changes are detected and persisted")
    func sttSettingsChangesArePersisted() async throws {
        // Load initial default config
        await viewModel.load()
        #expect(!viewModel.hasUnsavedChanges)

        // Change STT settings (simulating user interaction)
        viewModel.config.sttSettings.enabled = true
        viewModel.config.sttSettings.provider = .elevenlabs
        viewModel.config.sttSettings.model = "test-model"

        // Verify unsaved changes are detected
        #expect(viewModel.hasUnsavedChanges, "STT settings changes should be detected")

        // Save
        try await viewModel.save()
        #expect(!viewModel.hasUnsavedChanges)

        // Create new ViewModel (simulating navigation back to settings)
        let newViewModel = AISettingsViewModel(storage: storage, capabilityDetector: capabilityDetector)
        await newViewModel.load()

        // Verify STT settings persisted
        #expect(newViewModel.config.sttSettings.enabled == true)
        #expect(newViewModel.config.sttSettings.provider == .elevenlabs)
        #expect(newViewModel.config.sttSettings.model == "test-model")
    }

    @Test("Changes detected even when no saved config exists (regression test for nil originalConfig bug)")
    func changesDetectedWithoutSavedConfig() async throws {
        // Ensure no saved config exists
        try storage.clear()

        // Load - should use default config
        await viewModel.load()
        #expect(!viewModel.hasUnsavedChanges, "Should have no changes initially")

        // Make a change
        viewModel.config.ttsSettings.enabled = true

        // BUG: Previously, hasUnsavedChanges would return false because originalConfig was nil
        // FIX: originalConfig should be set to default config, not nil
        #expect(viewModel.hasUnsavedChanges, "Changes should be detected even without saved config")

        // Save should work
        try await viewModel.save()
        #expect(!viewModel.hasUnsavedChanges)

        // Verify it actually saved
        let newViewModel = AISettingsViewModel(storage: storage, capabilityDetector: capabilityDetector)
        await newViewModel.load()
        #expect(newViewModel.config.ttsSettings.enabled == true, "Settings should persist")
    }

    // MARK: - LLM Config CRUD Tests

    @Test("Add LLM configuration")
    func addLLMConfiguration() async throws {
        let config = LLMConfig(
            name: "Fast",
            provider: .openai,
            model: "gpt-4o-mini",
            id: "test-id"
        )

        try await viewModel.addLLMConfig(config, apiKey: "sk-test-key")

        #expect(viewModel.config.llmConfigs.count == 1)
        #expect(viewModel.config.llmConfigs.first?.id == "test-id")
        #expect(viewModel.config.activeLLMConfigID == "test-id")

        // Verify API key saved
        let key = try storage.loadAPIKey(for: "test-id")
        #expect(key == "sk-test-key")
    }

    @Test("Update LLM configuration")
    func updateLLMConfiguration() async throws {
        // Add initial config
        let config = LLMConfig(
            name: "Original",
            provider: .openai,
            model: "gpt-4",
            id: "test-id"
        )
        try await viewModel.addLLMConfig(config, apiKey: "sk-original")

        // Update
        let updated = LLMConfig(
            name: "Updated",
            provider: .anthropic,
            model: "claude-3-5-sonnet-20241022",
            id: "test-id"
        )
        try await viewModel.updateLLMConfig(updated, apiKey: "sk-updated")

        // Verify
        #expect(viewModel.config.llmConfigs.first?.name == "Updated")
        #expect(viewModel.config.llmConfigs.first?.provider == .anthropic)

        let key = try storage.loadAPIKey(for: "test-id")
        #expect(key == "sk-updated")
    }

    @Test("Remove LLM configuration")
    func removeLLMConfiguration() async throws {
        // Add config
        let config = LLMConfig(
            name: "ToRemove",
            provider: .openai,
            model: "gpt-4",
            id: "test-id"
        )
        try await viewModel.addLLMConfig(config, apiKey: "sk-test")

        // Remove
        try await viewModel.removeLLMConfig(id: "test-id")

        // Verify
        #expect(viewModel.config.llmConfigs.isEmpty)
        #expect(viewModel.config.activeLLMConfigID == nil)

        let key = try storage.loadAPIKey(for: "test-id")
        #expect(key == nil)
    }

    @Test("Set active LLM configuration")
    func setActiveLLMConfiguration() async throws {
        // Add two configs
        let config1 = LLMConfig(name: "Config1", provider: .openai, model: "gpt-4", id: "id1")
        let config2 = LLMConfig(
            name: "Config2",
            provider: .anthropic,
            model: "claude-3-5-sonnet-20241022",
            id: "id2"
        )

        try await viewModel.addLLMConfig(config1, apiKey: "key1")
        try await viewModel.addLLMConfig(config2, apiKey: "key2")

        // Set active
        try await viewModel.setActiveLLMConfig(id: "id2")

        // Verify
        #expect(viewModel.config.activeLLMConfigID == "id2")
    }

    @Test("Set feature assignment")
    func setFeatureAssignment() async throws {
        // Add config
        let config = LLMConfig(name: "Test", provider: .openai, model: "gpt-4", id: "test-id")
        try await viewModel.addLLMConfig(config, apiKey: "sk-test")

        // Set feature assignment
        try await viewModel.setFeatureAssignment(feature: .titleGeneration, configID: "test-id")

        // Verify
        #expect(viewModel.config.featureAssignments[.titleGeneration] == "test-id")
    }

    // MARK: - Capability Filtering Tests

    @Test("Filter LLM providers when Apple Intelligence unavailable")
    func filterLLMProvidersNoAppleIntelligence() async throws {
        let detector = MockAICapabilityDetector(
            appleIntelligenceAvailable: false,
            speechTranscriberAvailable: true
        )
        let vm = AISettingsViewModel(storage: storage, capabilityDetector: detector)

        #expect(!vm.availableLLMProviders.contains(.appleIntelligence))
        #expect(vm.availableLLMProviders.contains(.openai))
    }

    @Test("Include all LLM providers when capabilities available")
    func includeAllLLMProviders() async throws {
        #expect(viewModel.availableLLMProviders.contains(.appleIntelligence))
        #expect(viewModel.availableLLMProviders.contains(.openai))
        #expect(viewModel.availableLLMProviders.contains(.anthropic))
    }

    @Test("Filter STT providers when SpeechTranscriber unavailable")
    func filterSTTProvidersNoSpeechTranscriber() async throws {
        let detector = MockAICapabilityDetector(
            appleIntelligenceAvailable: false,
            speechTranscriberAvailable: false,
            whisperKitAvailable: true
        )
        let vm = AISettingsViewModel(storage: storage, capabilityDetector: detector)

        #expect(!vm.availableSTTProviders.contains(.speechTranscriber))
        #expect(vm.availableSTTProviders.contains(.whisper))
        #expect(vm.availableSTTProviders.contains(.whisperKit))
    }
}

// MARK: - AddLLMConfigViewModelTests

@MainActor
@Suite("AddLLMConfigViewModel Tests")
struct AddLLMConfigViewModelTests {
    @Test("Create new config with valid data")
    func createValidConfig() {
        let vm = AddLLMConfigViewModel(availableProviders: LLMProvider.allCases)
        vm.name = "Test Config"
        vm.provider = .openai
        vm.model = "gpt-4"
        vm.apiKey = "sk-test-key"

        #expect(vm.isValid)
        #expect(vm.validationError == nil)

        let config = vm.createConfig()
        #expect(config.name == "Test Config")
        #expect(config.provider == .openai)
        #expect(config.model == "gpt-4")
    }

    @Test("Validation fails with empty name")
    func validationFailsEmptyName() {
        let vm = AddLLMConfigViewModel(availableProviders: LLMProvider.allCases)
        vm.name = ""
        vm.model = "gpt-4"
        vm.apiKey = "sk-test"

        #expect(!vm.isValid)
        #expect(vm.validationError != nil)
    }

    @Test("Validation fails with empty model")
    func validationFailsEmptyModel() {
        let vm = AddLLMConfigViewModel(availableProviders: LLMProvider.allCases)
        vm.name = "Test"
        vm.model = ""
        vm.apiKey = "sk-test"

        #expect(!vm.isValid)
        #expect(vm.validationError != nil)
    }

    @Test("Validation fails with empty API key for non-Apple Intelligence")
    func validationFailsEmptyAPIKey() {
        let vm = AddLLMConfigViewModel(availableProviders: LLMProvider.allCases)
        vm.name = "Test"
        vm.provider = .openai
        vm.model = "gpt-4"
        vm.apiKey = ""

        #expect(!vm.isValid)
        #expect(vm.validationError != nil)
    }

    @Test("Validation requires base URL for Ollama")
    func validationRequiresBaseURLForOllama() {
        let vm = AddLLMConfigViewModel(availableProviders: LLMProvider.allCases)
        vm.name = "Ollama"
        vm.provider = .ollama
        vm.model = "llama3.1"
        vm.apiKey = "not-needed"
        vm.baseURL = ""

        #expect(!vm.isValid)
        #expect(vm.validationError != nil)
        #expect(vm.requiresBaseURL)
    }

    @Test("Validation succeeds with valid base URL")
    func validationSucceedsWithValidBaseURL() {
        let vm = AddLLMConfigViewModel(availableProviders: LLMProvider.allCases)
        vm.name = "Ollama"
        vm.provider = .ollama
        vm.model = "llama3.1"
        vm.apiKey = "not-needed"
        vm.baseURL = "http://localhost:11434"

        #expect(vm.isValid)
        #expect(vm.validationError == nil)

        let config = vm.createConfig()
        #expect(config.baseURL == "http://localhost:11434")
    }

    @Test("Provider help text is appropriate")
    func providerHelpText() {
        let vm = AddLLMConfigViewModel(availableProviders: LLMProvider.allCases)

        vm.provider = .openai
        #expect(vm.providerHelpText.contains("OpenAI"))

        vm.provider = .anthropic
        #expect(vm.providerHelpText.contains("Anthropic"))

        vm.provider = .ollama
        #expect(vm.providerHelpText.contains("Ollama"))
    }
}

// MARK: - VoiceSelectionViewModelTests

@MainActor
@Suite("VoiceSelectionViewModel Tests")
struct VoiceSelectionViewModelTests {
    @Test("Initialize with current voices")
    func initializeWithVoices() {
        let voices = [
            VoiceConfig(name: "Alloy", provider: .openai, voiceID: "alloy", id: "openai-alloy"),
        ]
        let vm = VoiceSelectionViewModel(currentVoices: voices)

        #expect(vm.selectedCount == 1)
        #expect(vm.isSelected("openai-alloy"))
    }

    @Test("Toggle voice selection")
    func toggleVoiceSelection() {
        let vm = VoiceSelectionViewModel(currentVoices: [])

        #expect(!vm.isSelected("openai-alloy"))

        vm.toggleVoice(id: "openai-alloy")
        #expect(vm.isSelected("openai-alloy"))
        #expect(vm.selectedCount == 1)

        vm.toggleVoice(id: "openai-alloy")
        #expect(!vm.isSelected("openai-alloy"))
        #expect(vm.selectedCount == 0)
    }

    @Test("Enforce maximum voice limit")
    func enforceMaximumVoices() {
        let vm = VoiceSelectionViewModel(currentVoices: [])

        // Select 10 voices
        for index in 0 ..< 10 {
            vm.toggleVoice(id: "voice-\(index)")
        }

        #expect(vm.selectedCount == 10)
        #expect(vm.isAtMaximum)

        // Try to select 11th voice
        vm.toggleVoice(id: "voice-11")
        #expect(vm.selectedCount == 10)
        #expect(!vm.isSelected("voice-11"))
    }

    @Test("Filter voices by provider")
    func filterByProvider() {
        let vm = VoiceSelectionViewModel(currentVoices: [])

        // All voices initially
        let allCount = vm.availableVoices.count
        #expect(allCount > 0)

        // Filter to OpenAI only
        vm.selectedProvider = .openai
        let openAICount = vm.availableVoices.count
        #expect(openAICount > 0)
        #expect(openAICount < allCount)
        #expect(vm.availableVoices.allSatisfy { $0.provider == .openai })
    }

    @Test("Filter voices by search query")
    func filterBySearchQuery() {
        let vm = VoiceSelectionViewModel(currentVoices: [])

        let allCount = vm.availableVoices.count

        // Search for "alloy"
        vm.searchQuery = "alloy"
        let filtered = vm.availableVoices
        #expect(filtered.count < allCount)
        #expect(filtered.contains { $0.name.lowercased().contains("alloy") })
    }

    @Test("Create voice configs from selection")
    func createVoiceConfigs() {
        let vm = VoiceSelectionViewModel(currentVoices: [])

        vm.toggleVoice(id: "openai-alloy")
        vm.toggleVoice(id: "openai-nova")

        let configs = vm.createVoiceConfigs()
        #expect(configs.count == 2)
        #expect(configs.contains { $0.id == "openai-alloy" })
        #expect(configs.contains { $0.id == "openai-nova" })
    }
}
