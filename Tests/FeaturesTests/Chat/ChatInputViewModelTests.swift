//
// ChatInputViewModelTests.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation
@testable import TENEXFeatures
import Testing

@Suite("ChatInputViewModel Tests")
@MainActor
struct ChatInputViewModelTests {
    // Helper to create a view model with in-memory storage
    private func makeViewModel(conversationID: String = "test-conv", isNewThread: Bool = false) -> ChatInputViewModel {
        ChatInputViewModel(
            conversationID: conversationID,
            isNewThread: isNewThread,
            draftStorage: InMemoryChatDraftStorage()
        )
    }

    @Test("Initialize with empty input")
    func initializeWithEmptyInput() async {
        // Given/When: Creating view model
        let viewModel = makeViewModel()

        // Wait for restore to complete
        try? await Task.sleep(nanoseconds: 100_000_000)

        // Then: View model starts with empty state
        #expect(viewModel.inputText.isEmpty)
        #expect(viewModel.selectedAgent == nil)
        #expect(viewModel.selectedBranch == nil)
        #expect(viewModel.canSend == false)
    }

    @Test("Enable send button when text is non-empty")
    func enableSendButtonWithText() async {
        // Given: View model with empty input
        let viewModel = makeViewModel()
        #expect(viewModel.canSend == false)

        // When: Entering text
        viewModel.inputText = "Hello"

        // Then: Send button is enabled
        #expect(viewModel.canSend == true)
    }

    @Test("Disable send button when text becomes empty")
    func disableSendButtonWhenTextEmpty() async {
        // Given: View model with text
        let viewModel = makeViewModel()
        viewModel.inputText = "Hello"
        #expect(viewModel.canSend == true)

        // When: Clearing text
        viewModel.inputText = ""

        // Then: Send button is disabled
        #expect(viewModel.canSend == false)
    }

    @Test("Disable send button with whitespace-only text")
    func disableSendButtonWithWhitespaceOnly() async {
        // Given: View model
        let viewModel = makeViewModel()

        // When: Entering whitespace
        viewModel.inputText = "   \n  \t  "

        // Then: Send button is disabled
        #expect(viewModel.canSend == false)
    }

    @Test("Select agent")
    func selectAgent() async {
        // Given: View model
        let viewModel = makeViewModel()

        // When: Selecting agent
        let agentID = "agent-123"
        viewModel.selectAgent(agentID)

        // Then: Agent is selected
        #expect(viewModel.selectedAgent == agentID)
    }

    @Test("Select branch")
    func selectBranch() async {
        // Given: View model
        let viewModel = makeViewModel()

        // When: Selecting branch
        let branchID = "branch-456"
        viewModel.selectBranch(branchID)

        // Then: Branch is selected
        #expect(viewModel.selectedBranch == branchID)
    }

    @Test("Clear input after sending")
    func clearInputAfterSending() async {
        // Given: View model with text
        let viewModel = makeViewModel()
        viewModel.inputText = "Hello world"

        // When: Clearing input
        viewModel.clearInput()

        // Then: Input is cleared
        #expect(viewModel.inputText.isEmpty)
        #expect(viewModel.canSend == false)
    }

    @Test("Preserve agent selection after clearing input")
    func preserveAgentSelectionAfterClear() async {
        // Given: View model with agent and text
        let viewModel = makeViewModel()
        viewModel.selectAgent("agent-123")
        viewModel.inputText = "Hello"

        // When: Clearing input
        viewModel.clearInput()

        // Then: Agent selection is preserved
        #expect(viewModel.selectedAgent == "agent-123")
    }

    @Test("Preserve branch selection after clearing input")
    func preserveBranchSelectionAfterClear() async {
        // Given: View model with branch and text
        let viewModel = makeViewModel()
        viewModel.selectBranch("branch-456")
        viewModel.inputText = "Hello"

        // When: Clearing input
        viewModel.clearInput()

        // Then: Branch selection is preserved
        #expect(viewModel.selectedBranch == "branch-456")
    }

    // MARK: - Draft Persistence Tests

    @Test("Save draft when text changes")
    func saveDraftWhenTextChanges() async throws {
        // Given: View model with shared storage
        let storage = InMemoryChatDraftStorage()
        let viewModel = ChatInputViewModel(
            conversationID: "conv-123",
            isNewThread: false,
            draftStorage: storage
        )

        // Wait for initial restore
        try await Task.sleep(nanoseconds: 100_000_000)

        // When: Entering text
        viewModel.inputText = "Hello world"

        // Wait for debounced save (600ms debounce + buffer)
        try await Task.sleep(nanoseconds: 700_000_000)

        // Then: Draft is saved
        let draft = try await storage.loadDraft(for: "conv-123")
        #expect(draft != nil)
        #expect(draft?.text == "Hello world")
    }

    @Test("Delete draft when text becomes empty")
    func deleteDraftWhenTextEmpty() async throws {
        // Given: View model with text
        let storage = InMemoryChatDraftStorage()
        let viewModel = ChatInputViewModel(
            conversationID: "conv-123",
            isNewThread: false,
            draftStorage: storage
        )

        // Wait for restore
        try await Task.sleep(nanoseconds: 100_000_000)

        viewModel.inputText = "Hello"

        // Wait for debounced save
        try await Task.sleep(nanoseconds: 700_000_000)

        // When: Clearing text
        viewModel.inputText = ""

        // Wait for immediate delete
        try await Task.sleep(nanoseconds: 100_000_000)

        // Then: Draft is deleted
        let draft = try await storage.loadDraft(for: "conv-123")
        #expect(draft == nil)
    }

    @Test("Restore draft on initialization")
    func restoreDraftOnInit() async throws {
        // Given: Storage with existing draft
        let storage = InMemoryChatDraftStorage()
        let existingDraft = ChatDraft(
            conversationID: "conv-123",
            text: "Restored text",
            selectedAgent: "agent-456",
            selectedBranch: "main",
            selectedNudges: ["nudge-1"],
            mentionedPubkeys: ["pubkey-1"]
        )
        try await storage.saveDraft(existingDraft)

        // When: Creating view model
        let viewModel = ChatInputViewModel(
            conversationID: "conv-123",
            isNewThread: false,
            draftStorage: storage
        )

        // Wait for restore
        try await Task.sleep(nanoseconds: 200_000_000)

        // Then: Draft is restored
        #expect(viewModel.inputText == "Restored text")
        #expect(viewModel.selectedAgent == "agent-456")
        #expect(viewModel.selectedBranch == "main")
        #expect(viewModel.selectedNudges == ["nudge-1"])
        #expect(viewModel.mentionedPubkeys == ["pubkey-1"])
    }

    @Test("Delete draft when clearing input")
    func deleteDraftWhenClearing() async throws {
        // Given: View model with text
        let storage = InMemoryChatDraftStorage()
        let viewModel = ChatInputViewModel(
            conversationID: "conv-123",
            isNewThread: false,
            draftStorage: storage
        )

        // Wait for restore
        try await Task.sleep(nanoseconds: 100_000_000)

        viewModel.inputText = "Hello world"

        // Wait for debounced save
        try await Task.sleep(nanoseconds: 700_000_000)

        let draftBefore = try await storage.loadDraft(for: "conv-123")
        #expect(draftBefore != nil)

        // When: Clearing input
        viewModel.clearInput()

        // Wait for delete
        try await Task.sleep(nanoseconds: 100_000_000)

        // Then: Draft is deleted
        let draft = try await storage.loadDraft(for: "conv-123")
        #expect(draft == nil)
    }

    @Test("Separate drafts for different conversations")
    func separateDraftsForConversations() async throws {
        // Given: Two view models with different conversation IDs
        let storage = InMemoryChatDraftStorage()
        let viewModel1 = ChatInputViewModel(
            conversationID: "conv-1",
            isNewThread: false,
            draftStorage: storage
        )
        let viewModel2 = ChatInputViewModel(
            conversationID: "conv-2",
            isNewThread: false,
            draftStorage: storage
        )

        // Wait for restores
        try await Task.sleep(nanoseconds: 100_000_000)

        // When: Setting different text
        viewModel1.inputText = "Text for conv 1"
        viewModel2.inputText = "Text for conv 2"

        // Wait for debounced saves
        try await Task.sleep(nanoseconds: 700_000_000)

        // Then: Each conversation has its own draft
        let draft1 = try await storage.loadDraft(for: "conv-1")
        let draft2 = try await storage.loadDraft(for: "conv-2")
        #expect(draft1?.text == "Text for conv 1")
        #expect(draft2?.text == "Text for conv 2")
    }

    @Test("Draft save is debounced on rapid typing")
    func draftSaveIsDebounced() async throws {
        // Given: View model with shared storage
        let storage = InMemoryChatDraftStorage()
        let viewModel = ChatInputViewModel(
            conversationID: "conv-123",
            isNewThread: false,
            draftStorage: storage
        )

        // Wait for restore
        try await Task.sleep(nanoseconds: 100_000_000)

        // When: Rapidly typing (simulating keystrokes)
        viewModel.inputText = "H"
        try await Task.sleep(nanoseconds: 50_000_000) // 50ms
        viewModel.inputText = "He"
        try await Task.sleep(nanoseconds: 50_000_000)
        viewModel.inputText = "Hel"
        try await Task.sleep(nanoseconds: 50_000_000)
        viewModel.inputText = "Hell"
        try await Task.sleep(nanoseconds: 50_000_000)
        viewModel.inputText = "Hello"

        // Then: Draft should not be saved yet (debounce not elapsed)
        try await Task.sleep(nanoseconds: 100_000_000)
        let draftBeforeDebounce = try await storage.loadDraft(for: "conv-123")
        #expect(draftBeforeDebounce == nil)

        // Wait for debounce to complete
        try await Task.sleep(nanoseconds: 600_000_000)

        // Then: Draft should now be saved with final text
        let draftAfterDebounce = try await storage.loadDraft(for: "conv-123")
        #expect(draftAfterDebounce?.text == "Hello")
    }

    @Test("Draft save error is tracked in view model")
    func draftSaveErrorIsTracked() async throws {
        // Given: View model with failing storage
        let storage = FailingChatDraftStorage()
        let viewModel = ChatInputViewModel(
            conversationID: "conv-123",
            isNewThread: false,
            draftStorage: storage
        )

        // Wait for restore attempt
        try await Task.sleep(nanoseconds: 100_000_000)

        // When: Entering text (which will fail to save)
        viewModel.inputText = "Hello world"

        // Wait for debounced save attempt
        try await Task.sleep(nanoseconds: 700_000_000)

        // Then: View model should track the error
        #expect(viewModel.draftSaveError != nil)
    }
}

// MARK: - Test Helpers

/// Failing storage for testing error handling
private actor FailingChatDraftStorage: ChatDraftStorage {
    func saveDraft(_ draft: ChatDraft) async throws {
        throw NSError(domain: "TestError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Simulated save failure"])
    }

    func loadDraft(for conversationID: String) async throws -> ChatDraft? {
        nil
    }

    func deleteDraft(for conversationID: String) async throws {
        // No-op
    }

    func loadAllDrafts() async throws -> [String: ChatDraft] {
        [:]
    }

    func clearAllDrafts() async throws {
        // No-op
    }
}
