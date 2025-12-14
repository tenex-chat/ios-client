//
// MentionAutocompleteViewModel.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation
import Observation
import TENEXCore

// MARK: - Mention

/// Represents an @mention in a message
public struct Mention: Equatable, Sendable {
    /// The agent's pubkey (used for p-tag)
    public let pubkey: String

    /// The agent's name (displayed in message)
    public let name: String

    /// Range of the mention in the text
    public let range: Range<String.Index>
}

// MARK: - MentionAutocompleteViewModel

/// View model for @mention autocomplete functionality
@MainActor
@Observable
public final class MentionAutocompleteViewModel {
    // MARK: Lifecycle

    /// Initialize with DataStore and project reference
    /// - Parameters:
    ///   - dataStore: The data store containing project statuses
    ///   - projectReference: The project coordinate to get agents for
    public init(dataStore: DataStore, projectReference: String) {
        self.dataStore = dataStore
        self.projectReference = projectReference
    }

    // MARK: Public

    /// Filtered agents based on current query
    public private(set) var filteredAgents: [ProjectAgent] = []

    /// Whether the autocomplete popup should be visible
    public private(set) var isVisible = false

    /// Currently selected index for keyboard navigation
    public var selectedIndex = 0

    /// Detected mentions in the current input
    public private(set) var mentions: [Mention] = []

    /// All available agents from project status
    public var agents: [ProjectAgent] {
        dataStore.getProjectStatus(projectCoordinate: projectReference)?.agents ?? []
    }

    /// Update the input text and detect @mention trigger
    /// - Parameters:
    ///   - text: The current input text
    ///   - cursorPosition: The current cursor position
    public func updateInput(text: String, cursorPosition: Int) {
        currentText = text
        currentCursorPosition = cursorPosition
        detectMentionTrigger()
    }

    /// Select the currently highlighted agent
    /// - Returns: The text to insert, or nil if no selection
    public func selectCurrentAgent() -> (replacement: String, pubkey: String)? {
        guard isVisible,
              selectedIndex >= 0,
              selectedIndex < filteredAgents.count,
              triggerRange != nil
        else {
            return nil
        }

        let agent = filteredAgents[selectedIndex]
        hide()

        // Return the text to replace and the pubkey for p-tag
        return (replacement: "@\(agent.name) ", pubkey: agent.pubkey)
    }

    /// Select agent at specific index
    /// - Parameter index: The index to select
    /// - Returns: The text to insert, or nil if invalid index
    public func selectAgent(at index: Int) -> (replacement: String, pubkey: String)? {
        guard isVisible,
              index >= 0,
              index < filteredAgents.count,
              triggerRange != nil
        else {
            return nil
        }

        selectedIndex = index
        return selectCurrentAgent()
    }

    /// Move selection up
    public func moveSelectionUp() {
        guard isVisible, !filteredAgents.isEmpty else {
            return
        }
        selectedIndex = (selectedIndex - 1 + filteredAgents.count) % filteredAgents.count
    }

    /// Move selection down
    public func moveSelectionDown() {
        guard isVisible, !filteredAgents.isEmpty else {
            return
        }
        selectedIndex = (selectedIndex + 1) % filteredAgents.count
    }

    /// Hide the autocomplete popup
    public func hide() {
        isVisible = false
        filteredAgents = []
        selectedIndex = 0
        triggerRange = nil
        currentQuery = ""
    }

    /// Get the range to replace when inserting a mention
    public func getRangeToReplace() -> Range<String.Index>? {
        triggerRange
    }

    // MARK: Private

    @ObservationIgnored private let dataStore: DataStore
    @ObservationIgnored private let projectReference: String

    private var currentText = ""
    private var currentCursorPosition = 0
    private var currentQuery = ""
    private var triggerRange: Range<String.Index>?

    private func detectMentionTrigger() {
        guard currentCursorPosition <= currentText.count else {
            hide()
            return
        }

        let cursorIndex = currentText.index(
            currentText.startIndex,
            offsetBy: currentCursorPosition,
            limitedBy: currentText.endIndex
        ) ?? currentText.endIndex

        // Look backwards from cursor for @ trigger
        var searchIndex = cursorIndex
        var foundAt = false
        var query = ""

        while searchIndex > currentText.startIndex {
            let prevIndex = currentText.index(before: searchIndex)
            let char = currentText[prevIndex]

            if char == "@" {
                // Check if @ is at start OR preceded by whitespace
                if prevIndex == currentText.startIndex {
                    foundAt = true
                    triggerRange = prevIndex ..< cursorIndex
                } else {
                    let beforeAt = currentText.index(before: prevIndex)
                    let charBeforeAt = currentText[beforeAt]
                    if charBeforeAt.isWhitespace || charBeforeAt.isNewline {
                        foundAt = true
                        triggerRange = prevIndex ..< cursorIndex
                    }
                }
                break
            } else if char.isWhitespace || char.isNewline {
                // Hit whitespace before finding @, no trigger
                break
            } else {
                query = String(char) + query
                searchIndex = prevIndex
            }
        }

        // Check for @ at start of string (cursor right after @)
        if !foundAt, searchIndex == currentText.startIndex, !currentText.isEmpty {
            let firstChar = currentText[currentText.startIndex]
            if firstChar == "@" {
                foundAt = true
                triggerRange = currentText.startIndex ..< cursorIndex
            }
        }

        if foundAt {
            currentQuery = query
            filterAgents()
            isVisible = !filteredAgents.isEmpty
            selectedIndex = 0
        } else {
            hide()
        }
    }

    private func filterAgents() {
        if currentQuery.isEmpty {
            filteredAgents = agents
        } else {
            let lowercaseQuery = currentQuery.lowercased()
            filteredAgents = agents.filter { agent in
                agent.name.lowercased().contains(lowercaseQuery)
            }
        }
    }
}
