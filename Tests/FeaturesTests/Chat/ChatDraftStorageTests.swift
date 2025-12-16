//
// ChatDraftStorageTests.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

@testable import TENEXFeatures
import Foundation
import Testing

@MainActor
@Suite("ChatDraftStorage Tests")
struct ChatDraftStorageTests {
    @Test("Save and load draft")
    func saveAndLoadDraft() async throws {
        // Given: Storage and a draft
        let storage = InMemoryChatDraftStorage()
        let draft = ChatDraft(
            conversationID: "conv-123",
            text: "Hello world",
            selectedAgent: "agent-456",
            selectedBranch: "main",
            selectedNudges: ["nudge-1", "nudge-2"],
            mentionedPubkeys: ["pubkey-1"]
        )

        // When: Saving draft
        try await storage.saveDraft(draft)

        // Then: Draft can be loaded
        let loadedDraft = try await storage.loadDraft(for: "conv-123")
        #expect(loadedDraft != nil)
        #expect(loadedDraft?.text == "Hello world")
        #expect(loadedDraft?.selectedAgent == "agent-456")
        #expect(loadedDraft?.selectedBranch == "main")
        #expect(loadedDraft?.selectedNudges == ["nudge-1", "nudge-2"])
        #expect(loadedDraft?.mentionedPubkeys == ["pubkey-1"])
    }

    @Test("Load non-existent draft returns nil")
    func loadNonExistentDraft() async throws {
        // Given: Empty storage
        let storage = InMemoryChatDraftStorage()

        // When: Loading non-existent draft
        let draft = try await storage.loadDraft(for: "nonexistent")

        // Then: Returns nil
        #expect(draft == nil)
    }

    @Test("Delete draft")
    func deleteDraft() async throws {
        // Given: Storage with a draft
        let storage = InMemoryChatDraftStorage()
        let draft = ChatDraft(conversationID: "conv-123", text: "Hello")
        try await storage.saveDraft(draft)

        // When: Deleting draft
        try await storage.deleteDraft(for: "conv-123")

        // Then: Draft no longer exists
        let loadedDraft = try await storage.loadDraft(for: "conv-123")
        #expect(loadedDraft == nil)
    }

    @Test("Update existing draft")
    func updateExistingDraft() async throws {
        // Given: Storage with a draft
        let storage = InMemoryChatDraftStorage()
        let draft1 = ChatDraft(conversationID: "conv-123", text: "First text")
        try await storage.saveDraft(draft1)

        // When: Saving new draft with same conversation ID
        let draft2 = ChatDraft(conversationID: "conv-123", text: "Updated text")
        try await storage.saveDraft(draft2)

        // Then: Draft is updated
        let loadedDraft = try await storage.loadDraft(for: "conv-123")
        #expect(loadedDraft?.text == "Updated text")
    }

    @Test("Save multiple drafts for different conversations")
    func saveMultipleDrafts() async throws {
        // Given: Storage
        let storage = InMemoryChatDraftStorage()
        let draft1 = ChatDraft(conversationID: "conv-1", text: "Text 1")
        let draft2 = ChatDraft(conversationID: "conv-2", text: "Text 2")

        // When: Saving multiple drafts
        try await storage.saveDraft(draft1)
        try await storage.saveDraft(draft2)

        // Then: Both drafts are saved
        let loaded1 = try await storage.loadDraft(for: "conv-1")
        let loaded2 = try await storage.loadDraft(for: "conv-2")
        #expect(loaded1?.text == "Text 1")
        #expect(loaded2?.text == "Text 2")
    }

    @Test("Load all drafts")
    func loadAllDrafts() async throws {
        // Given: Storage with multiple drafts
        let storage = InMemoryChatDraftStorage()
        let draft1 = ChatDraft(conversationID: "conv-1", text: "Text 1")
        let draft2 = ChatDraft(conversationID: "conv-2", text: "Text 2")
        try await storage.saveDraft(draft1)
        try await storage.saveDraft(draft2)

        // When: Loading all drafts
        let allDrafts = try await storage.loadAllDrafts()

        // Then: All drafts are returned
        #expect(allDrafts.count == 2)
        #expect(allDrafts["conv-1"]?.text == "Text 1")
        #expect(allDrafts["conv-2"]?.text == "Text 2")
    }

    @Test("Clear all drafts")
    func clearAllDrafts() async throws {
        // Given: Storage with multiple drafts
        let storage = InMemoryChatDraftStorage()
        let draft1 = ChatDraft(conversationID: "conv-1", text: "Text 1")
        let draft2 = ChatDraft(conversationID: "conv-2", text: "Text 2")
        try await storage.saveDraft(draft1)
        try await storage.saveDraft(draft2)

        // When: Clearing all drafts
        try await storage.clearAllDrafts()

        // Then: No drafts remain
        let allDrafts = try await storage.loadAllDrafts()
        #expect(allDrafts.isEmpty)
    }

    @Test("Draft isEmpty for empty text")
    func draftIsEmptyForEmptyText() {
        // Given: Draft with empty text
        let draft = ChatDraft(conversationID: "conv-123", text: "")

        // Then: isEmpty returns true
        #expect(draft.isEmpty == true)
    }

    @Test("Draft isEmpty for whitespace-only text")
    func draftIsEmptyForWhitespaceText() {
        // Given: Draft with whitespace-only text
        let draft = ChatDraft(conversationID: "conv-123", text: "   \n  \t  ")

        // Then: isEmpty returns true
        #expect(draft.isEmpty == true)
    }

    @Test("Draft is not empty for meaningful text")
    func draftNotEmptyForMeaningfulText() {
        // Given: Draft with meaningful text
        let draft = ChatDraft(conversationID: "conv-123", text: "Hello world")

        // Then: isEmpty returns false
        #expect(draft.isEmpty == false)
    }

    @Test("Concurrent saves do not corrupt data")
    func concurrentSavesDoNotCorruptData() async throws {
        // Given: Storage and multiple drafts
        let storage = InMemoryChatDraftStorage()

        // When: Saving multiple drafts concurrently
        await withTaskGroup(of: Void.self) { group in
            for i in 1...10 {
                group.addTask {
                    let draft = ChatDraft(conversationID: "conv-\(i)", text: "Text \(i)")
                    try? await storage.saveDraft(draft)
                }
            }
        }

        // Then: All drafts should be saved correctly
        let allDrafts = try await storage.loadAllDrafts()
        #expect(allDrafts.count == 10)
        for i in 1...10 {
            #expect(allDrafts["conv-\(i)"]?.text == "Text \(i)")
        }
    }
}
