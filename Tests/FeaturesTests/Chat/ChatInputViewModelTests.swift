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
    @Test("Initialize with empty input")
    func initializeWithEmptyInput() {
        // Given/When: Creating view model
        let viewModel = ChatInputViewModel()

        // Then: View model starts with empty state
        #expect(viewModel.inputText.isEmpty)
        #expect(viewModel.selectedAgent == nil)
        #expect(viewModel.selectedBranch == nil)
        #expect(viewModel.canSend == false)
    }

    @Test("Enable send button when text is non-empty")
    func enableSendButtonWithText() {
        // Given: View model with empty input
        let viewModel = ChatInputViewModel()
        #expect(viewModel.canSend == false)

        // When: Entering text
        viewModel.inputText = "Hello"

        // Then: Send button is enabled
        #expect(viewModel.canSend == true)
    }

    @Test("Disable send button when text becomes empty")
    func disableSendButtonWhenTextEmpty() {
        // Given: View model with text
        let viewModel = ChatInputViewModel()
        viewModel.inputText = "Hello"
        #expect(viewModel.canSend == true)

        // When: Clearing text
        viewModel.inputText = ""

        // Then: Send button is disabled
        #expect(viewModel.canSend == false)
    }

    @Test("Disable send button with whitespace-only text")
    func disableSendButtonWithWhitespaceOnly() {
        // Given: View model
        let viewModel = ChatInputViewModel()

        // When: Entering whitespace
        viewModel.inputText = "   \n  \t  "

        // Then: Send button is disabled
        #expect(viewModel.canSend == false)
    }

    @Test("Select agent")
    func selectAgent() {
        // Given: View model
        let viewModel = ChatInputViewModel()

        // When: Selecting agent
        let agentID = "agent-123"
        viewModel.selectAgent(agentID)

        // Then: Agent is selected
        #expect(viewModel.selectedAgent == agentID)
    }

    @Test("Select branch")
    func selectBranch() {
        // Given: View model
        let viewModel = ChatInputViewModel()

        // When: Selecting branch
        let branchID = "branch-456"
        viewModel.selectBranch(branchID)

        // Then: Branch is selected
        #expect(viewModel.selectedBranch == branchID)
    }

    @Test("Clear input after sending")
    func clearInputAfterSending() {
        // Given: View model with text
        let viewModel = ChatInputViewModel()
        viewModel.inputText = "Hello world"

        // When: Clearing input
        viewModel.clearInput()

        // Then: Input is cleared
        #expect(viewModel.inputText.isEmpty)
        #expect(viewModel.canSend == false)
    }

    @Test("Preserve agent selection after clearing input")
    func preserveAgentSelectionAfterClear() {
        // Given: View model with agent and text
        let viewModel = ChatInputViewModel()
        viewModel.selectAgent("agent-123")
        viewModel.inputText = "Hello"

        // When: Clearing input
        viewModel.clearInput()

        // Then: Agent selection is preserved
        #expect(viewModel.selectedAgent == "agent-123")
    }

    @Test("Preserve branch selection after clearing input")
    func preserveBranchSelectionAfterClear() {
        // Given: View model with branch and text
        let viewModel = ChatInputViewModel()
        viewModel.selectBranch("branch-456")
        viewModel.inputText = "Hello"

        // When: Clearing input
        viewModel.clearInput()

        // Then: Branch selection is preserved
        #expect(viewModel.selectedBranch == "branch-456")
    }
}
