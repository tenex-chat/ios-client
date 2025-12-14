//
// ThreadFiltersStore.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation
import Observation

// MARK: - ThreadFilter

/// Filter options for thread lists
public enum ThreadFilter: String, CaseIterable, Codable {
    /// Show threads with activity in the last hour
    case oneHour = "1h"
    /// Show threads with activity in the last 4 hours
    case fourHours = "4h"
    /// Show threads with activity in the last 24 hours
    case oneDay = "1d"
    /// Show threads needing a response within 1 hour
    case needsResponseOneHour = "needs-response-1h"
    /// Show threads needing a response within 4 hours
    case needsResponseFourHours = "needs-response-4h"
    /// Show threads needing a response within 24 hours
    case needsResponseOneDay = "needs-response-1d"

    // MARK: Public

    /// Display name for the filter
    public var displayName: String {
        switch self {
        case .oneHour:
            "Active in last hour"
        case .fourHours:
            "Active in last 4 hours"
        case .oneDay:
            "Active in last 24 hours"
        case .needsResponseOneHour:
            "Needs response (1h)"
        case .needsResponseFourHours:
            "Needs response (4h)"
        case .needsResponseOneDay:
            "Needs response (1d)"
        }
    }

    /// Time threshold in seconds for the filter
    public var thresholdSeconds: TimeInterval {
        switch self {
        case .oneHour,
             .needsResponseOneHour:
            60 * 60
        case .fourHours,
             .needsResponseFourHours:
            4 * 60 * 60
        case .oneDay,
             .needsResponseOneDay:
            24 * 60 * 60
        }
    }

    /// Whether this is a "needs response" filter
    public var isNeedsResponseFilter: Bool {
        switch self {
        case .needsResponseOneHour,
             .needsResponseFourHours,
             .needsResponseOneDay:
            true
        case .oneHour,
             .fourHours,
             .oneDay:
            false
        }
    }

    /// System image for the filter
    public var systemImage: String {
        isNeedsResponseFilter ? "message.badge.fill" : "clock.fill"
    }
}

// MARK: - ThreadFiltersStore

/// Store for persisting thread filter selections per project
@MainActor
@Observable
public final class ThreadFiltersStore {
    // MARK: Lifecycle

    /// Initialize the thread filters store and load saved filters from UserDefaults
    public init() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([String: ThreadFilter].self, from: data) {
            filters = decoded
        }
    }

    // MARK: Public

    /// Get the active filter for a project
    /// - Parameter projectID: The project coordinate
    /// - Returns: The active filter, or nil if no filter is set
    public func getFilter(for projectID: String) -> ThreadFilter? {
        filters[projectID]
    }

    /// Set the filter for a project
    /// - Parameters:
    ///   - filter: The filter to set, or nil to clear the filter
    ///   - projectID: The project coordinate
    public func setFilter(_ filter: ThreadFilter?, for projectID: String) {
        if let filter {
            filters[projectID] = filter
        } else {
            filters.removeValue(forKey: projectID)
        }
        save()
    }

    // MARK: Private

    private var filters: [String: ThreadFilter] = [:]
    private let storageKey = "thread-filters"

    /// Save the current filters to UserDefaults
    private func save() {
        if let encoded = try? JSONEncoder().encode(filters) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
    }
}
