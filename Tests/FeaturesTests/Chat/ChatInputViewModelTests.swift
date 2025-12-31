//
// ChatInputViewModelTests.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation
@testable import TENEXFeatures
import Testing

@MainActor
@Suite("ChatInputViewModel Tests")
struct ChatInputViewModelTests {
    // MARK: - Hashtag Extraction Tests

    @Test("extractedHashtags returns empty array for text without hashtags")
    func extractedHashtagsEmptyForNoHashtags() {
        // Given: ViewModel with text containing no hashtags
        let viewModel = ChatInputViewModel(conversationID: "test", isNewThread: true)
        viewModel.inputText = "Hello world"

        // Then: extractedHashtags is empty
        #expect(viewModel.extractedHashtags.isEmpty)
    }

    @Test("extractedHashtags extracts single hashtag from text")
    func extractedHashtagsSingleHashtag() {
        // Given: ViewModel with text containing one hashtag
        let viewModel = ChatInputViewModel(conversationID: "test", isNewThread: true)
        viewModel.inputText = "Hello #world"

        // Then: extractedHashtags contains "world"
        #expect(viewModel.extractedHashtags == ["world"])
    }

    @Test("extractedHashtags extracts multiple hashtags from text")
    func extractedHashtagsMultipleHashtags() {
        // Given: ViewModel with text containing multiple hashtags
        let viewModel = ChatInputViewModel(conversationID: "test", isNewThread: true)
        viewModel.inputText = "Hello #world and #swift"

        // Then: extractedHashtags contains both (in order of appearance)
        #expect(viewModel.extractedHashtags == ["world", "swift"])
    }

    @Test("extractedHashtags lowercases hashtags")
    func extractedHashtagsLowercase() {
        // Given: ViewModel with mixed-case hashtag
        let viewModel = ChatInputViewModel(conversationID: "test", isNewThread: true)
        viewModel.inputText = "Hello #WORLD #Swift"

        // Then: extractedHashtags are lowercased
        #expect(viewModel.extractedHashtags == ["world", "swift"])
    }

    @Test("extractedHashtags handles hashtag at start of text")
    func extractedHashtagsAtStart() {
        // Given: ViewModel with hashtag at the start
        let viewModel = ChatInputViewModel(conversationID: "test", isNewThread: true)
        viewModel.inputText = "#hello world"

        // Then: extractedHashtags contains "hello"
        #expect(viewModel.extractedHashtags == ["hello"])
    }

    @Test("extractedHashtags ignores duplicate hashtags")
    func extractedHashtagsNoDuplicates() {
        // Given: ViewModel with duplicate hashtags
        let viewModel = ChatInputViewModel(conversationID: "test", isNewThread: true)
        viewModel.inputText = "Hello #world and #world again"

        // Then: extractedHashtags contains "world" only once
        #expect(viewModel.extractedHashtags == ["world"])
    }

    // MARK: - canSend with Content Hashtags Tests

    @Test("canSend returns true for new thread with content hashtag only")
    func canSendWithContentHashtagOnly() {
        // Given: New thread with text containing hashtag, no selected agent/hashtag
        let viewModel = ChatInputViewModel(conversationID: "test", isNewThread: true)
        viewModel.inputText = "Hello #world"

        // Then: canSend is true (content hashtag satisfies routing requirement)
        #expect(viewModel.canSend == true)
    }

    @Test("canSend returns false for new thread without any routing")
    func canSendFalseWithoutRouting() {
        // Given: New thread with text but no hashtags or selected agent
        let viewModel = ChatInputViewModel(conversationID: "test", isNewThread: true)
        viewModel.inputText = "Hello world"

        // Then: canSend is false (no routing)
        #expect(viewModel.canSend == false)
    }

    @Test("canSend returns true for new thread with selected agent")
    func canSendWithSelectedAgent() {
        // Given: New thread with selected agent
        let viewModel = ChatInputViewModel(conversationID: "test", isNewThread: true)
        viewModel.inputText = "Hello world"
        viewModel.selectAgent("agent-pubkey")

        // Then: canSend is true
        #expect(viewModel.canSend == true)
    }

    @Test("canSend returns true for new thread with selected hashtag")
    func canSendWithSelectedHashtag() {
        // Given: New thread with selected hashtag from dropdown
        let viewModel = ChatInputViewModel(conversationID: "test", isNewThread: true)
        viewModel.inputText = "Hello world"
        viewModel.selectedHashtag = "topic"

        // Then: canSend is true
        #expect(viewModel.canSend == true)
    }

    @Test("canSend returns true for reply without any routing")
    func canSendReplyWithoutRouting() {
        // Given: Reply (not new thread) with text but no routing
        let viewModel = ChatInputViewModel(conversationID: "test", isNewThread: false)
        viewModel.inputText = "Hello world"

        // Then: canSend is true (replies don't require routing)
        #expect(viewModel.canSend == true)
    }

    @Test("canSend returns false for empty text even with content hashtag")
    func canSendFalseForEmptyText() {
        // Given: New thread with only whitespace
        let viewModel = ChatInputViewModel(conversationID: "test", isNewThread: true)
        viewModel.inputText = "   "

        // Then: canSend is false (no meaningful text)
        #expect(viewModel.canSend == false)
    }

    // MARK: - firstExtractedHashtag Tests

    @Test("firstExtractedHashtag returns first hashtag from content")
    func firstExtractedHashtagReturnsFirst() {
        // Given: ViewModel with multiple hashtags
        let viewModel = ChatInputViewModel(conversationID: "test", isNewThread: true)
        viewModel.inputText = "Hello #world and #swift"

        // Then: firstExtractedHashtag returns "world"
        #expect(viewModel.firstExtractedHashtag == "world")
    }

    @Test("firstExtractedHashtag returns nil for text without hashtags")
    func firstExtractedHashtagNilForNoHashtags() {
        // Given: ViewModel without hashtags
        let viewModel = ChatInputViewModel(conversationID: "test", isNewThread: true)
        viewModel.inputText = "Hello world"

        // Then: firstExtractedHashtag is nil
        #expect(viewModel.firstExtractedHashtag == nil)
    }
}
