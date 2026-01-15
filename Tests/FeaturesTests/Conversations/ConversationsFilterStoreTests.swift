//
// ConversationsFilterStoreTests.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation
@testable import TENEXFeatures
import Testing

@Suite("ConversationsFilterStore Tests")
@MainActor
struct ConversationsFilterStoreTests {
    // MARK: - Setup/Teardown

    private func cleanupUserDefaults() {
        UserDefaults.standard.removeObject(forKey: "conversations-time-filter")
        UserDefaults.standard.removeObject(forKey: "conversations-selected-projects")
        UserDefaults.standard.removeObject(forKey: "conversations-show-archived")
    }

    // MARK: - Initial State Tests

    @Test("FilterStore starts with default values")
    func startsWithDefaults() async throws {
        cleanupUserDefaults()

        let store = ConversationsFilterStore()

        #expect(store.timeFilter == .all)
        #expect(store.selectedProjectCoordinates.isEmpty)
        #expect(store.showArchived == false)
        #expect(store.hasProjectFilter == false)
        #expect(store.selectedProjectCount == 0)

        cleanupUserDefaults()
    }

    // MARK: - Time Filter Tests

    @Test("Time filter can be set")
    func setTimeFilter() async throws {
        cleanupUserDefaults()

        let store = ConversationsFilterStore()
        store.setTimeFilter(.oneHour)

        #expect(store.timeFilter == .oneHour)

        cleanupUserDefaults()
    }

    @Test("Time filter persists across instances")
    func timeFilterPersists() async throws {
        cleanupUserDefaults()

        let store1 = ConversationsFilterStore()
        store1.setTimeFilter(.fourHours)

        let store2 = ConversationsFilterStore()
        #expect(store2.timeFilter == .fourHours)

        cleanupUserDefaults()
    }

    // MARK: - Project Filter Tests

    @Test("Project selection works correctly")
    func projectSelection() async throws {
        cleanupUserDefaults()

        let store = ConversationsFilterStore()
        let projectCoordinate = "31933:pubkey:test-project"

        // Initially all projects are shown (no filter)
        #expect(store.isProjectSelected(projectCoordinate) == true)
        #expect(store.hasProjectFilter == false)

        // Toggle to select specific project
        store.toggleProject(projectCoordinate)
        #expect(store.hasProjectFilter == true)
        #expect(store.isProjectSelected(projectCoordinate) == true)
        #expect(store.selectedProjectCount == 1)

        // Other projects should not be selected when filter is active
        #expect(store.isProjectSelected("other-project") == false)

        cleanupUserDefaults()
    }

    @Test("Clear project filter shows all projects")
    func clearProjectFilter() async throws {
        cleanupUserDefaults()

        let store = ConversationsFilterStore()
        store.toggleProject("project1")
        store.toggleProject("project2")

        #expect(store.hasProjectFilter == true)

        store.clearProjectFilter()

        #expect(store.hasProjectFilter == false)
        #expect(store.isProjectSelected("any-project") == true)

        cleanupUserDefaults()
    }

    @Test("Select only project replaces selection")
    func selectOnlyProject() async throws {
        cleanupUserDefaults()

        let store = ConversationsFilterStore()
        store.toggleProject("project1")
        store.toggleProject("project2")

        #expect(store.selectedProjectCount == 2)

        store.selectOnlyProject("project3")

        #expect(store.selectedProjectCount == 1)
        #expect(store.isProjectSelected("project3") == true)
        #expect(store.isProjectSelected("project1") == false)

        cleanupUserDefaults()
    }

    @Test("Project selection persists across instances")
    func projectSelectionPersists() async throws {
        cleanupUserDefaults()

        let store1 = ConversationsFilterStore()
        store1.toggleProject("test-project")

        let store2 = ConversationsFilterStore()
        #expect(store2.hasProjectFilter == true)
        #expect(store2.isProjectSelected("test-project") == true)

        cleanupUserDefaults()
    }

    // MARK: - Archive Filter Tests

    @Test("Show archived can be toggled")
    func toggleShowArchived() async throws {
        cleanupUserDefaults()

        let store = ConversationsFilterStore()
        #expect(store.showArchived == false)

        store.toggleShowArchived()
        #expect(store.showArchived == true)

        store.toggleShowArchived()
        #expect(store.showArchived == false)

        cleanupUserDefaults()
    }

    // MARK: - Reset Tests

    @Test("Reset all filters returns to defaults")
    func resetAllFilters() async throws {
        cleanupUserDefaults()

        let store = ConversationsFilterStore()
        store.setTimeFilter(.oneDay)
        store.toggleProject("project1")
        store.setShowArchived(true)

        store.resetAllFilters()

        #expect(store.timeFilter == .all)
        #expect(store.hasProjectFilter == false)
        #expect(store.showArchived == false)

        cleanupUserDefaults()
    }
}
