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

    /// Event kinds to sync for each project
    public static let syncEventKinds: [Int] = [11, 513, 1111, 21_111]

    /// Maximum number of events to fetch per project
    public static let maxEventsPerProject = 500

    /// Timeout for collecting events from a subscription
    public static let subscriptionTimeout: TimeInterval = 30.0

    /// Maximum number of sync history entries to keep
    public static let maxHistoryCount = 50

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

            do {
                let result = try await syncProject(project)
                projectResults.append(result)

                logger.info("""
                Completed sync for project: \(project.title)
                - Events: \(result.totalEvents)
                - Duration: \(String(format: "%.2f", result.duration))s
                """)
            } catch {
                logger.error("Failed to sync project \(project.title): \(error.localizedDescription)")
                // Create empty result for failed sync
                projectResults.append(ProjectSyncResult(
                    projectCoordinate: project.coordinate,
                    projectName: project.title,
                    totalEvents: 0,
                    eventsByKind: [:],
                    startTime: Date(),
                    endTime: Date()
                ))
            }
        }

        // Create sync run record
        let syncRun = SyncRun(
            id: UUID(),
            startTime: startTime,
            endTime: Date(),
            projectResults: projectResults
        )

        // Add to history (most recent first) with memory limit
        syncHistory.insert(syncRun, at: 0)
        if syncHistory.count > Self.maxHistoryCount {
            syncHistory.removeLast()
        }

        // Clear progress
        currentProgress = nil

        logger.info("Sync completed: \(syncRun.totalEvents) events across \(projects.count) projects")
    }

    // MARK: Private

    private let ndk: NDK
    private let logger = Logger(subsystem: "com.tenex.ios", category: "SyncManager")

    /// Sync a single project using negentropy
    private func syncProject(_ project: Project) async throws -> ProjectSyncResult {
        let projectStartTime = Date()

        // Filter for all event kinds related to this project
        let filter = NDKFilter(
            kinds: Self.syncEventKinds,
            limit: Self.maxEventsPerProject,
            tags: ["a": Set([project.coordinate])]
        )

        var eventsByKind: [Int: Int] = [:]
        var totalEvents = 0

        // Use NDK subscription with collect to gather all events
        let subscription = ndk.subscribe(filter: filter)

        // Collect events with timeout
        let events = await subscription.collect(
            timeout: Self.subscriptionTimeout,
            limit: Self.maxEventsPerProject
        )

        // Process all collected events at once
        for event in events {
            totalEvents += 1
            eventsByKind[event.kind, default: 0] += 1
        }

        // Update progress once after collection completes
        if let progress = currentProgress {
            currentProgress = SyncProgress(
                currentProjectIndex: progress.currentProjectIndex,
                totalProjects: progress.totalProjects,
                currentProject: progress.currentProject,
                eventsReceived: totalEvents,
                eventsByKind: eventsByKind
            )
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
