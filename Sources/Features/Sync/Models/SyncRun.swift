//
// SyncModels.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation

// MARK: - SyncRun

/// Record of a complete sync operation across all projects
public struct SyncRun: Identifiable, Sendable {
    /// Unique identifier for this sync run
    public let id: UUID

    /// When the sync started
    public let startTime: Date

    /// When the sync completed (nil if in progress)
    public let endTime: Date?

    /// Results for each project synced
    public let projectResults: [ProjectSyncResult]

    /// Total events received across all projects
    public var totalEvents: Int {
        projectResults.reduce(0) { $0 + $1.totalEvents }
    }

    /// Duration of the sync
    public var duration: TimeInterval? {
        guard let endTime else {
            return nil
        }
        return endTime.timeIntervalSince(startTime)
    }

    /// Whether the sync is still in progress
    public var isInProgress: Bool {
        endTime == nil
    }
}

// MARK: - ProjectSyncResult

/// Result of syncing a single project
public struct ProjectSyncResult: Identifiable, Sendable {
    /// Project coordinate (used as ID)
    public var id: String { projectCoordinate }

    /// Project coordinate (kind:pubkey:dTag)
    public let projectCoordinate: String

    /// Project display name
    public let projectName: String

    /// Total events received for this project
    public let totalEvents: Int

    /// Breakdown of events by kind (kind -> count)
    public let eventsByKind: [Int: Int]

    /// When this project's sync started
    public let startTime: Date

    /// When this project's sync completed
    public let endTime: Date

    /// Duration of this project's sync
    public var duration: TimeInterval {
        endTime.timeIntervalSince(startTime)
    }
}

// MARK: - SyncProgress

/// Real-time progress of an ongoing sync
public struct SyncProgress: Sendable {
    /// Current project index (0-based)
    public let currentProjectIndex: Int

    /// Total number of projects to sync
    public let totalProjects: Int

    /// Current project being synced
    public let currentProject: String

    /// Events received so far for current project
    public let eventsReceived: Int

    /// Event kind breakdown for current project
    public let eventsByKind: [Int: Int]

    /// Overall progress (0.0 to 1.0)
    public var progress: Double {
        guard totalProjects > 0 else {
            return 0
        }
        return Double(currentProjectIndex) / Double(totalProjects)
    }
}
