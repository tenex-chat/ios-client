//
// MentionAutocompleteViewModelTests.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation
import TENEXCore
@testable import TENEXFeatures
import Testing

@Suite("MentionAutocompleteViewModel Tests")
@MainActor
struct MentionAutocompleteViewModelTests {
    // MARK: Internal

    // MARK: - Tests

    @Test("Initialize with agents")
    func initializeWithAgents() {
        // Given/When
        let agents = makeAgents()
        let viewModel = MentionAutocompleteViewModel(agents: agents)

        // Then
        #expect(viewModel.agents.count == 3)
        #expect(viewModel.isVisible == false)
        #expect(viewModel.filteredAgents.isEmpty)
    }

    @Test("Show autocomplete when @ is typed")
    func showAutocompleteOnAtSymbol() {
        // Given
        let viewModel = MentionAutocompleteViewModel(agents: makeAgents())

        // When: User types @
        viewModel.updateInput(text: "@", cursorPosition: 1)

        // Then: Autocomplete shows all agents
        #expect(viewModel.isVisible == true)
        #expect(viewModel.filteredAgents.count == 3)
    }

    @Test("Filter agents by query")
    func filterAgentsByQuery() {
        // Given
        let viewModel = MentionAutocompleteViewModel(agents: makeAgents())

        // When: User types @Cl
        viewModel.updateInput(text: "@Cl", cursorPosition: 3)

        // Then: Only Claude matches
        #expect(viewModel.isVisible == true)
        #expect(viewModel.filteredAgents.count == 1)
        #expect(viewModel.filteredAgents[0].name == "Claude")
    }

    @Test("Filter is case insensitive")
    func filterIsCaseInsensitive() {
        // Given
        let viewModel = MentionAutocompleteViewModel(agents: makeAgents())

        // When: User types lowercase query
        viewModel.updateInput(text: "@claude", cursorPosition: 7)

        // Then: Still matches Claude
        #expect(viewModel.isVisible == true)
        #expect(viewModel.filteredAgents.count == 1)
        #expect(viewModel.filteredAgents[0].name == "Claude")
    }

    @Test("Hide when no matches")
    func hideWhenNoMatches() {
        // Given
        let viewModel = MentionAutocompleteViewModel(agents: makeAgents())

        // When: User types query with no matches
        viewModel.updateInput(text: "@xyz", cursorPosition: 4)

        // Then: Autocomplete is hidden
        #expect(viewModel.isVisible == false)
        #expect(viewModel.filteredAgents.isEmpty)
    }

    @Test("Hide when @ is removed")
    func hideWhenAtRemoved() {
        // Given: Autocomplete is visible
        let viewModel = MentionAutocompleteViewModel(agents: makeAgents())
        viewModel.updateInput(text: "@", cursorPosition: 1)
        #expect(viewModel.isVisible == true)

        // When: @ is removed
        viewModel.updateInput(text: "", cursorPosition: 0)

        // Then: Autocomplete is hidden
        #expect(viewModel.isVisible == false)
    }

    @Test("Detect @ after space")
    func detectAtAfterSpace() {
        // Given
        let viewModel = MentionAutocompleteViewModel(agents: makeAgents())

        // When: User types "hello @"
        viewModel.updateInput(text: "hello @", cursorPosition: 7)

        // Then: Autocomplete shows
        #expect(viewModel.isVisible == true)
        #expect(viewModel.filteredAgents.count == 3)
    }

    @Test("Don't trigger on email-like patterns")
    func dontTriggerOnEmail() {
        // Given
        let viewModel = MentionAutocompleteViewModel(agents: makeAgents())

        // When: User types text that looks like email (no space before @)
        viewModel.updateInput(text: "email@", cursorPosition: 6)

        // Then: Autocomplete is hidden (@ must be preceded by whitespace or start of string)
        #expect(viewModel.isVisible == false)
    }

    @Test("Select agent returns replacement text and pubkey")
    func selectAgentReturnsReplacementAndPubkey() {
        // Given: Autocomplete showing
        let viewModel = MentionAutocompleteViewModel(agents: makeAgents())
        viewModel.updateInput(text: "@Cl", cursorPosition: 3)

        // When: Selecting the agent
        let result = viewModel.selectCurrentAgent()

        // Then: Returns proper replacement and pubkey
        #expect(result?.replacement == "@Claude ")
        #expect(result?.pubkey == "abc123")
        #expect(viewModel.isVisible == false)
    }

    @Test("Move selection down")
    func moveSelectionDown() {
        // Given: Autocomplete showing
        let viewModel = MentionAutocompleteViewModel(agents: makeAgents())
        viewModel.updateInput(text: "@", cursorPosition: 1)
        #expect(viewModel.selectedIndex == 0)

        // When: Moving down
        viewModel.moveSelectionDown()

        // Then: Selection moves to next agent
        #expect(viewModel.selectedIndex == 1)
    }

    @Test("Move selection up")
    func moveSelectionUp() {
        // Given: Autocomplete showing with selection at index 1
        let viewModel = MentionAutocompleteViewModel(agents: makeAgents())
        viewModel.updateInput(text: "@", cursorPosition: 1)
        viewModel.moveSelectionDown()
        #expect(viewModel.selectedIndex == 1)

        // When: Moving up
        viewModel.moveSelectionUp()

        // Then: Selection moves back
        #expect(viewModel.selectedIndex == 0)
    }

    @Test("Selection wraps around")
    func selectionWrapsAround() {
        // Given: Autocomplete at last item
        let viewModel = MentionAutocompleteViewModel(agents: makeAgents())
        viewModel.updateInput(text: "@", cursorPosition: 1)
        viewModel.selectedIndex = 2

        // When: Moving down
        viewModel.moveSelectionDown()

        // Then: Wraps to first
        #expect(viewModel.selectedIndex == 0)
    }

    @Test("Selection wraps up from first")
    func selectionWrapsUpFromFirst() {
        // Given: Autocomplete at first item
        let viewModel = MentionAutocompleteViewModel(agents: makeAgents())
        viewModel.updateInput(text: "@", cursorPosition: 1)
        #expect(viewModel.selectedIndex == 0)

        // When: Moving up
        viewModel.moveSelectionUp()

        // Then: Wraps to last
        #expect(viewModel.selectedIndex == 2)
    }

    @Test("Select agent at specific index")
    func selectAgentAtIndex() {
        // Given: Autocomplete showing
        let viewModel = MentionAutocompleteViewModel(agents: makeAgents())
        viewModel.updateInput(text: "@", cursorPosition: 1)

        // When: Selecting agent at index 1
        let result = viewModel.selectAgent(at: 1)

        // Then: Returns GPT-4
        #expect(result?.replacement == "@GPT-4 ")
        #expect(result?.pubkey == "def456")
    }

    @Test("Hide clears state")
    func hideClearsState() {
        // Given: Autocomplete showing with selection
        let viewModel = MentionAutocompleteViewModel(agents: makeAgents())
        viewModel.updateInput(text: "@G", cursorPosition: 2)
        viewModel.moveSelectionDown()

        // When: Hiding
        viewModel.hide()

        // Then: State is cleared
        #expect(viewModel.isVisible == false)
        #expect(viewModel.filteredAgents.isEmpty)
        #expect(viewModel.selectedIndex == 0)
    }

    @Test("Update agents while visible")
    func updateAgentsWhileVisible() {
        // Given: Autocomplete visible
        let viewModel = MentionAutocompleteViewModel(agents: makeAgents())
        viewModel.updateInput(text: "@", cursorPosition: 1)
        #expect(viewModel.filteredAgents.count == 3)

        // When: Updating agents
        let newAgents = [
            ProjectAgent(pubkey: "new1", name: "NewAgent", isGlobal: false),
        ]
        viewModel.updateAgents(newAgents)

        // Then: Filtered list updates
        #expect(viewModel.filteredAgents.count == 1)
        #expect(viewModel.filteredAgents[0].name == "NewAgent")
    }

    // MARK: Private

    // MARK: - Test Helpers

    private func makeAgents() -> [ProjectAgent] {
        [
            ProjectAgent(pubkey: "abc123", name: "Claude", isGlobal: true, model: "claude-sonnet-4"),
            ProjectAgent(pubkey: "def456", name: "GPT-4", isGlobal: false, model: "gpt-4-turbo"),
            ProjectAgent(pubkey: "ghi789", name: "Gemini", isGlobal: false),
        ]
    }
}
