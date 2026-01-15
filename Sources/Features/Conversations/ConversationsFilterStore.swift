//
// ConversationsFilterStore.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation
import Observation

// MARK: - TimeFilter

/// Time-based filter options for conversations
public enum TimeFilter: String, CaseIterable, Codable, Identifiable {
    /// Show all conversations (no time filter)
    case all = "all"
    /// Show conversations with activity in the last hour
    case oneHour = "1h"
    /// Show conversations with activity in the last 4 hours
    case fourHours = "4h"
    /// Show conversations with activity in the last 24 hours
    case oneDay = "1d"
    /// Show conversations with activity in the last week
    case oneWeek = "1w"

    // MARK: Public

    public var id: String { rawValue }

    /// Display name for the filter
    public var displayName: String {
        switch self {
        case .all:
            "All time"
        case .oneHour:
            "Last hour"
        case .fourHours:
            "Last 4 hours"
        case .oneDay:
            "Last 24 hours"
        case .oneWeek:
            "Last week"
        }
    }

    /// Time threshold in seconds for the filter (nil for .all)
    public var thresholdSeconds: TimeInterval? {
        switch self {
        case .all:
            nil
        case .oneHour:
            60 * 60
        case .fourHours:
            4 * 60 * 60
        case .oneDay:
            24 * 60 * 60
        case .oneWeek:
            7 * 24 * 60 * 60
        }
    }

    /// System image for the filter
    public var systemImage: String {
        switch self {
        case .all:
            "infinity"
        case .oneHour,
             .fourHours,
             .oneDay,
             .oneWeek:
            "clock"
        }
    }
}

// MARK: - ConversationsFilterStore

/// Store for persisting conversation filters including project selection and time filters
@MainActor
@Observable
public final class ConversationsFilterStore {
    // MARK: Lifecycle

    /// Initialize the filter store and load saved state from UserDefaults
    public init() {
        // Load time filter
        if let rawValue = UserDefaults.standard.string(forKey: timeFilterKey),
           let filter = TimeFilter(rawValue: rawValue) {
            timeFilter = filter
        }

        // Load selected projects (empty means show all)
        if let data = UserDefaults.standard.data(forKey: selectedProjectsKey),
           let decoded = try? JSONDecoder().decode(Set<String>.self, from: data) {
            selectedProjectCoordinates = decoded
        }

        // Load show archived setting
        showArchived = UserDefaults.standard.bool(forKey: showArchivedKey)
    }

    // MARK: Public

    /// The active time filter
    public private(set) var timeFilter: TimeFilter = .all

    /// Set of selected project coordinates to show (empty means show all)
    public private(set) var selectedProjectCoordinates: Set<String> = []

    /// Whether to show archived conversations
    public private(set) var showArchived: Bool = false

    /// Whether any project filter is active (not showing all projects)
    public var hasProjectFilter: Bool {
        !selectedProjectCoordinates.isEmpty
    }

    /// Number of selected projects for display
    public var selectedProjectCount: Int {
        selectedProjectCoordinates.count
    }

    // MARK: - Time Filter Methods

    /// Set the time filter
    /// - Parameter filter: The new time filter
    public func setTimeFilter(_ filter: TimeFilter) {
        timeFilter = filter
        saveTimeFilter()
    }

    // MARK: - Project Filter Methods

    /// Check if a project is selected (visible)
    /// - Parameter coordinate: The project coordinate
    /// - Returns: True if the project is selected or if no filter is active (show all)
    public func isProjectSelected(_ coordinate: String) -> Bool {
        // If no projects are explicitly selected, show all
        if selectedProjectCoordinates.isEmpty {
            return true
        }
        return selectedProjectCoordinates.contains(coordinate)
    }

    /// Toggle selection for a project
    /// - Parameter coordinate: The project coordinate to toggle
    public func toggleProject(_ coordinate: String) {
        if selectedProjectCoordinates.contains(coordinate) {
            selectedProjectCoordinates.remove(coordinate)
        } else {
            selectedProjectCoordinates.insert(coordinate)
        }
        saveSelectedProjects()
    }

    /// Select specific projects (replaces current selection)
    /// - Parameter coordinates: Set of project coordinates to select
    public func selectProjects(_ coordinates: Set<String>) {
        selectedProjectCoordinates = coordinates
        saveSelectedProjects()
    }

    /// Clear project filter (show all projects)
    public func clearProjectFilter() {
        selectedProjectCoordinates.removeAll()
        saveSelectedProjects()
    }

    /// Select only a single project
    /// - Parameter coordinate: The project coordinate to select exclusively
    public func selectOnlyProject(_ coordinate: String) {
        selectedProjectCoordinates = [coordinate]
        saveSelectedProjects()
    }

    // MARK: - Archive Filter Methods

    /// Toggle showing archived conversations
    public func toggleShowArchived() {
        showArchived.toggle()
        saveShowArchived()
    }

    /// Set whether to show archived conversations
    /// - Parameter show: Whether to show archived
    public func setShowArchived(_ show: Bool) {
        showArchived = show
        saveShowArchived()
    }

    // MARK: - Reset

    /// Reset all filters to defaults
    public func resetAllFilters() {
        timeFilter = .all
        selectedProjectCoordinates.removeAll()
        showArchived = false
        saveTimeFilter()
        saveSelectedProjects()
        saveShowArchived()
    }

    // MARK: Private

    private let timeFilterKey = "conversations-time-filter"
    private let selectedProjectsKey = "conversations-selected-projects"
    private let showArchivedKey = "conversations-show-archived"

    private func saveTimeFilter() {
        UserDefaults.standard.set(timeFilter.rawValue, forKey: timeFilterKey)
    }

    private func saveSelectedProjects() {
        if let encoded = try? JSONEncoder().encode(selectedProjectCoordinates) {
            UserDefaults.standard.set(encoded, forKey: selectedProjectsKey)
        }
    }

    private func saveShowArchived() {
        UserDefaults.standard.set(showArchived, forKey: showArchivedKey)
    }
}
