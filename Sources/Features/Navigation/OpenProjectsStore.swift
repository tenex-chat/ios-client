//
// OpenProjectsStore.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation
import SwiftUI

// MARK: - OpenProjectsStore

/// Manages the state of open projects in the multi-project column view
@MainActor
@Observable
public final class OpenProjectsStore {
    // MARK: Lifecycle

    /// Initialize the store and load persisted state
    public init() {
        openProjectIDs = Self.loadFromUserDefaults()
    }

    // MARK: Public

    /// Array of project IDs currently open as columns
    public private(set) var openProjectIDs: [String] {
        didSet {
            Self.saveToUserDefaults(openProjectIDs)
        }
    }

    // MARK: - Operations

    /// Toggle a project's open state
    /// - Parameter projectID: The project ID to toggle
    public func toggle(_ projectID: String) {
        if openProjectIDs.contains(projectID) {
            close(projectID)
        } else {
            open(projectID)
        }
    }

    /// Open a project (add to columns)
    /// - Parameter projectID: The project ID to open
    public func open(_ projectID: String) {
        guard !openProjectIDs.contains(projectID) else {
            return
        }
        openProjectIDs.append(projectID)
    }

    /// Close a project (remove from columns)
    /// - Parameter projectID: The project ID to close
    public func close(_ projectID: String) {
        openProjectIDs.removeAll { $0 == projectID }
    }

    /// Check if a project is currently open
    /// - Parameter projectID: The project ID to check
    /// - Returns: True if the project is open, false otherwise
    public func isOpen(_ projectID: String) -> Bool {
        openProjectIDs.contains(projectID)
    }

    // MARK: - Persistence

    private static let userDefaultsKey = "tenex.openProjects"

    /// Load open projects from UserDefaults
    private static func loadFromUserDefaults() -> [String] {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let projectIDs = try? JSONDecoder().decode([String].self, from: data)
        {
            return projectIDs
        }
        return []
    }

    /// Save open projects to UserDefaults
    private static func saveToUserDefaults(_ projectIDs: [String]) {
        if let data = try? JSONEncoder().encode(projectIDs) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
    }
}
