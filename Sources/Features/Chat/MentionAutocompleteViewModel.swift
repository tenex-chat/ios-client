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

    /// Whether the autocomplete popup should be visible
    public private(set) var isVisible = false

    /// Currently selected index for keyboard navigation
    public var selectedIndex = 0

    /// Detected mentions in the current input
    public private(set) var mentions: [Mention] = []

    /// Filtered agents based on current query
    public var filteredAgents: [ProjectAgent] {
        if self.currentQuery.isEmpty {
            return self.agents
        } else {
            let lowercaseQuery = self.currentQuery.lowercased()
            return self.agents.filter { agent in
                agent.name.lowercased().contains(lowercaseQuery)
            }
        }
    }

    /// All available agents from project status
    public var agents: [ProjectAgent] {
        self.dataStore.getProjectStatus(projectCoordinate: self.projectReference)?.agents ?? []
    }

    /// Update the input text and detect @mention trigger
    /// - Parameters:
    ///   - text: The current input text
    ///   - cursorPosition: The current cursor position
    public func updateInput(text: String, cursorPosition: Int) {
        self.currentText = text
        self.currentCursorPosition = cursorPosition
        self.detectMentionTrigger()
    }

    /// Select the currently highlighted agent
    /// - Returns: The text to insert, or nil if no selection
    public func selectCurrentAgent() -> (replacement: String, pubkey: String)? {
        guard self.isVisible,
              self.selectedIndex >= 0,
              self.selectedIndex < self.filteredAgents.count,
              self.triggerRange != nil
        else {
            return nil
        }

        let agent = self.filteredAgents[self.selectedIndex]
        self.hide()

        // Return the text to replace and the pubkey for p-tag
        return (replacement: "@\(agent.name) ", pubkey: agent.pubkey)
    }

    /// Select agent at specific index
    /// - Parameter index: The index to select
    /// - Returns: The text to insert, or nil if invalid index
    public func selectAgent(at index: Int) -> (replacement: String, pubkey: String)? {
        guard self.isVisible,
              index >= 0,
              index < self.filteredAgents.count,
              self.triggerRange != nil
        else {
            return nil
        }

        self.selectedIndex = index
        return self.selectCurrentAgent()
    }

    /// Move selection up
    public func moveSelectionUp() {
        guard self.isVisible, !self.filteredAgents.isEmpty else {
            return
        }
        self.selectedIndex = (self.selectedIndex - 1 + self.filteredAgents.count) % self.filteredAgents.count
    }

    /// Move selection down
    public func moveSelectionDown() {
        guard self.isVisible, !self.filteredAgents.isEmpty else {
            return
        }
        self.selectedIndex = (self.selectedIndex + 1) % self.filteredAgents.count
    }

    /// Hide the autocomplete popup
    public func hide() {
        self.isVisible = false
        self.selectedIndex = 0
        self.triggerRange = nil
        self.currentQuery = ""
    }

    /// Get the range to replace when inserting a mention
    public func getRangeToReplace() -> Range<String.Index>? {
        self.triggerRange
    }

    // MARK: Private

    @ObservationIgnored private let dataStore: DataStore
    @ObservationIgnored private let projectReference: String

    private var currentText = ""
    private var currentCursorPosition = 0
    private var currentQuery = ""
    private var triggerRange: Range<String.Index>?

    private func detectMentionTrigger() {
        guard self.currentCursorPosition <= self.currentText.count else {
            self.hide()
            return
        }

        let cursorIndex = self.currentText.index(
            self.currentText.startIndex,
            offsetBy: self.currentCursorPosition,
            limitedBy: self.currentText.endIndex
        ) ?? self.currentText.endIndex

        // Look backwards from cursor for @ trigger
        var searchIndex = cursorIndex
        var foundAt = false
        var query = ""

        while searchIndex > self.currentText.startIndex {
            let prevIndex = self.currentText.index(before: searchIndex)
            let char = self.currentText[prevIndex]

            if char == "@" {
                // Check if @ is at start OR preceded by whitespace
                if prevIndex == self.currentText.startIndex {
                    foundAt = true
                    self.triggerRange = prevIndex ..< cursorIndex
                } else {
                    let beforeAt = self.currentText.index(before: prevIndex)
                    let charBeforeAt = self.currentText[beforeAt]
                    if charBeforeAt.isWhitespace || charBeforeAt.isNewline {
                        foundAt = true
                        self.triggerRange = prevIndex ..< cursorIndex
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
        if !foundAt, searchIndex == self.currentText.startIndex, !self.currentText.isEmpty {
            let firstChar = self.currentText[self.currentText.startIndex]
            if firstChar == "@" {
                foundAt = true
                self.triggerRange = self.currentText.startIndex ..< cursorIndex
            }
        }

        if foundAt {
            self.currentQuery = query
            self.isVisible = !self.filteredAgents.isEmpty
            self.selectedIndex = 0
        } else {
            self.hide()
        }
    }
}
