//
// ProjectGroup.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation
import SwiftUI

/// Represents a client-side grouping of projects for organization
public struct ProjectGroup: Identifiable, Codable, Sendable, Equatable {
    // MARK: Lifecycle

    /// Initialize a new project group
    /// - Parameters:
    ///   - name: Group name
    ///   - projectIDs: Array of project IDs
    ///   - id: Unique identifier (defaults to UUID)
    ///   - createdAt: Creation date (defaults to now)
    public init(
        name: String,
        projectIDs: [String],
        id: String = UUID().uuidString,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.projectIDs = projectIDs
        self.createdAt = createdAt
    }

    // MARK: Public

    /// Unique identifier for the group
    public let id: String

    /// Name of the group
    public var name: String

    /// Array of project IDs included in this group
    public var projectIDs: [String]

    /// When the group was created
    public let createdAt: Date

    /// Deterministic color generated from the group name
    public var color: Color {
        Color.deterministicColor(for: name)
    }
}
