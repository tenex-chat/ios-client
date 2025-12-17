//
// SyncHistoryView.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import SwiftUI
import TENEXCore

// MARK: - SyncHistoryView

/// View showing sync history and controls
public struct SyncHistoryView: View {
    // MARK: Lifecycle

    public init(syncManager: SyncManager, projects: [Project]) {
        self.syncManager = syncManager
        self.projects = projects
    }

    // MARK: Public

    public var body: some View {
        List {
            controlSection
            if syncManager.isSyncing {
                progressSection
            }
            historySection
        }
        .navigationTitle("Sync")
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    // MARK: Private

    private let syncManager: SyncManager
    private let projects: [Project]

    @ViewBuilder
    private var controlSection: some View {
        Section {
            Button {
                Task {
                    await syncManager.syncAllProjects(projects)
                }
            } label: {
                HStack {
                    Label("Sync All Projects", systemImage: "arrow.triangle.2.circlepath")
                    Spacer()
                    if syncManager.isSyncing {
                        ProgressView()
                    }
                }
            }
            .disabled(syncManager.isSyncing || projects.isEmpty)

            if projects.isEmpty {
                Text("No projects to sync")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("\(projects.count) project(s)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var progressSection: some View {
        if let progress = syncManager.currentProgress {
            Section("Syncing") {
                SyncProgressContent(progress: progress)
                    .padding(.vertical, 4)
            }
        }
    }

    @ViewBuilder
    private var historySection: some View {
        Section("History") {
            if syncManager.syncHistory.isEmpty {
                Text("No sync history")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(syncManager.syncHistory) { syncRun in
                    SyncRunRow(syncRun: syncRun)
                }
            }
        }
    }
}

// MARK: - SyncProgressContent

private struct SyncProgressContent: View {
    let progress: SyncProgress

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            progressBar
            currentProjectRow
            eventsReceivedRow
            if !progress.eventsByKind.isEmpty {
                kindBreakdown
            }
        }
    }

    private var progressBar: some View {
        ProgressView(value: progress.progress) {
            Text("Project \(progress.currentProjectIndex + 1) of \(progress.totalProjects)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var currentProjectRow: some View {
        HStack {
            Text("Current:")
            Spacer()
            Text(progress.currentProject)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }

    private var eventsReceivedRow: some View {
        HStack {
            Text("Events:")
            Spacer()
            Text("\(progress.eventsReceived)")
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }

    private var kindBreakdown: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("By Kind:")
                .font(.caption)
                .foregroundStyle(.tertiary)
            ForEach(progress.eventsByKind.sorted { $0.key < $1.key }, id: \.key) { kind, count in
                HStack {
                    Text("Kind \(kind):")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Spacer()
                    Text("\(count)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.top, 4)
    }
}

// MARK: - SyncRunRow

private struct SyncRunRow: View {
    let syncRun: SyncRun

    var body: some View {
        NavigationLink {
            SyncRunDetailView(syncRun: syncRun)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(formatDate(syncRun.startTime))
                        .font(.body)
                    Spacer()
                    if syncRun.isInProgress {
                        ProgressView()
                            .controlSize(.small)
                    }
                }

                HStack {
                    Text("\(syncRun.projectResults.count) projects")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("•")
                        .foregroundStyle(.tertiary)
                    Text("\(syncRun.totalEvents) events")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let duration = syncRun.duration {
                        Text("•")
                            .foregroundStyle(.tertiary)
                        Text(String(format: "%.1fs", duration))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    private func formatDate(_ date: Date) -> String {
        Self.dateFormatter.string(from: date)
    }
}

// MARK: - SyncRunDetailView

private struct SyncRunDetailView: View {
    let syncRun: SyncRun

    var body: some View {
        List {
            summarySection
            projectsSection
        }
        .navigationTitle("Sync Details")
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    @ViewBuilder
    private var summarySection: some View {
        Section("Summary") {
            LabeledContent("Started") {
                Text(formatDateTime(syncRun.startTime))
                    .font(.system(.body, design: .monospaced))
            }

            if let endTime = syncRun.endTime {
                LabeledContent("Completed") {
                    Text(formatDateTime(endTime))
                        .font(.system(.body, design: .monospaced))
                }
            }

            if let duration = syncRun.duration {
                LabeledContent("Duration") {
                    Text(String(format: "%.2f seconds", duration))
                        .font(.system(.body, design: .monospaced))
                }
            }

            LabeledContent("Total Events") {
                Text("\(syncRun.totalEvents)")
                    .font(.system(.body, design: .monospaced))
            }

            LabeledContent("Projects") {
                Text("\(syncRun.projectResults.count)")
                    .font(.system(.body, design: .monospaced))
            }
        }
    }

    @ViewBuilder
    private var projectsSection: some View {
        Section("Projects") {
            ForEach(syncRun.projectResults) { result in
                ProjectResultRow(result: result)
            }
        }
    }

    private static let dateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter
    }()

    private func formatDateTime(_ date: Date) -> String {
        Self.dateTimeFormatter.string(from: date)
    }
}

// MARK: - ProjectResultRow

private struct ProjectResultRow: View {
    let result: ProjectSyncResult

    @State private var isExpanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Duration:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(String(format: "%.2f seconds", result.duration))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                if !result.eventsByKind.isEmpty {
                    Divider()
                    Text("Events by Kind")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    ForEach(result.eventsByKind.sorted { $0.key < $1.key }, id: \.key) { kind, count in
                        HStack {
                            Text(kindName(kind))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(count)")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .padding(.vertical, 4)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(result.projectName)
                        .font(.body)
                    Text("\(result.totalEvents) events")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
    }

    private func kindName(_ kind: Int) -> String {
        switch kind {
        case 11:
            return "Kind 11 (Threads)"
        case 513:
            return "Kind 513 (Updates)"
        case 1111:
            return "Kind 1111 (Messages)"
        case 21_111:
            return "Kind 21111 (Agent Messages)"
        default:
            return "Kind \(kind)"
        }
    }
}
