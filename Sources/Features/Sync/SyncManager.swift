//
// SyncManager.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation
import NDKSwiftCore
import Observation
import os
import TENEXCore

// MARK: - SyncManager

/// Manages negentropy-based synchronization for all projects
@MainActor
@Observable
public final class SyncManager {
    // MARK: Lifecycle

    /// Initialize the sync manager
    /// - Parameter ndk: The NDK instance for event subscriptions
    public init(ndk: NDK) {
        self.ndk = ndk
    }

    // MARK: Public

    /// All sync runs (most recent first)
    public private(set) var syncHistory: [SyncRun] = []

    /// Current sync progress (nil if not syncing)
    public private(set) var currentProgress: SyncProgress?

    /// Whether a sync is currently in progress
    public var isSyncing: Bool {
        currentProgress != nil
    }

    /// Start syncing all projects
    /// - Parameter projects: Array of projects to sync
    public func syncAllProjects(_ projects: [Project]) async {
        guard !isSyncing else {
            logger.warning("Sync already in progress, ignoring request")
            return
        }

        logger.info("Starting sync for \(projects.count) projects")

        let startTime = Date()
        var projectResults: [ProjectSyncResult] = []

        // Sync each project sequentially
        for (index, project) in projects.enumerated() {
            currentProgress = SyncProgress(
                currentProjectIndex: index,
                totalProjects: projects.count,
                currentProject: project.title,
                eventsReceived: 0,
                eventsByKind: [:]
            )

            let result = await syncProject(project)
            projectResults.append(result)

            logger.info("""
            Completed sync for project: \(project.title)
            - Events: \(result.totalEvents)
            - Duration: \(String(format: "%.2f", result.duration))s
            """)
        }

        // Create sync run record
        let syncRun = SyncRun(
            id: UUID(),
            startTime: startTime,
            endTime: Date(),
            projectResults: projectResults
        )

        // Add to history (most recent first)
        syncHistory.insert(syncRun, at: 0)

        // Clear progress
        currentProgress = nil

        logger.info("Sync completed: \(syncRun.totalEvents) events across \(projects.count) projects")
    }

    // MARK: Private

    private let ndk: NDK
    private let logger = Logger(subsystem: "com.tenex.ios", category: "SyncManager")

    /// Sync a single project using negentropy
    private func syncProject(_ project: Project) async -> ProjectSyncResult {
        let projectStartTime = Date()

        // Filter for all event kinds related to this project
        // kinds: 11 (threads), 513 (thread updates), 1111 (messages), 21111 (agent messages)
        let filter = NDKFilter(
            kinds: [11, 513, 1111, 21_111],
            limit: 500,
            tags: ["a": Set([project.coordinate])]
        )

        var eventsByKind: [Int: Int] = [:]
        var totalEvents = 0

        // Use NDK subscription with collect to gather all events
        let subscription = ndk.subscribe(filter: filter)

        // Collect events with timeout
        let events = await subscription.collect(timeout: 30.0, limit: 500)

        // Process collected events
        for event in events {
            totalEvents += 1
            eventsByKind[event.kind, default: 0] += 1

            // Update progress in real-time
            if var progress = currentProgress {
                progress = SyncProgress(
                    currentProjectIndex: progress.currentProjectIndex,
                    totalProjects: progress.totalProjects,
                    currentProject: progress.currentProject,
                    eventsReceived: totalEvents,
                    eventsByKind: eventsByKind
                )
                currentProgress = progress
            }
        }

        return ProjectSyncResult(
            projectCoordinate: project.coordinate,
            projectName: project.title,
            totalEvents: totalEvents,
            eventsByKind: eventsByKind,
            startTime: projectStartTime,
            endTime: Date()
        )
    }
}
