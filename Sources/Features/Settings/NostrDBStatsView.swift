//
// NostrDBStatsView.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import NDKSwiftCore
import NDKSwiftNostrDB
import SwiftUI
import TENEXShared

// MARK: - NdbStatCounts Extension

extension NdbStatCounts {
    // swiftlint:disable:next empty_count
    var isEmpty: Bool { count == 0 }
}

// MARK: - NostrDBStatsView

/// View for displaying NostrDB cache statistics and analytics
struct NostrDBStatsView: View {
    // MARK: Lifecycle

    init() {}

    // MARK: Internal

    var body: some View {
        Group {
            if let ndk {
                self.contentView(ndk: ndk)
            } else {
                Text("NDK not available")
            }
        }
    }

    // MARK: Private

    @Environment(\.ndk) private var ndk
    @State private var stats: NdbStat?
    @State private var databaseSize: Int64 = 0
    @State private var cachePath: String?
    @State private var inMemoryCount = 0
    @State private var isLoading = true
    @State private var error: String?

    @ViewBuilder private var contentSection: some View {
        if self.isLoading {
            self.loadingSection
        } else if let error {
            self.errorSection(error)
        } else if let stats {
            self.overviewSection(stats)
            self.eventsByKindSection(stats)
            self.databaseIndexesSection(stats)
            self.storageDetailsSection
        } else {
            self.notAvailableSection
        }
    }

    private var loadingSection: some View {
        Section {
            HStack {
                ProgressView()
                Text("Loading statistics...")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var notAvailableSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "cylinder.split.1x2.fill")
                        .foregroundStyle(.blue)
                    Text("NostrDB Cache Not Available")
                        .font(.headline)
                }

                Text("The cache is using a different backend (not NostrDB). Stats are only available with NostrDB.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("Tip: Restart the app to retry cache initialization.")
                    .font(.caption)
                    .foregroundStyle(.blue)
            }
            .padding(.vertical, 8)
        }
    }

    private var storageDetailsSection: some View {
        Section("Storage Details") {
            if let cachePath {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Cache Path")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(cachePath)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                }
                .padding(.vertical, 4)

                Button {
                    self.copyToClipboard(cachePath)
                } label: {
                    Label("Copy Path", systemImage: "doc.on.doc")
                }
            }
        }
    }

    private func errorSection(_ message: String) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text("Error Loading Stats")
                        .font(.headline)
                }

                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 8)
        }
    }

    private func overviewSection(_ stats: NdbStat) -> some View {
        Section("Overview") {
            HStack {
                Text("Total Events")
                Spacer()
                Text(FormattingUtilities.formatCount(stats.totalEvents))
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text("Total Storage")
                Spacer()
                Text(FormattingUtilities.formatBytes(Int64(stats.totalStorageSize)))
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text("Database Files")
                Spacer()
                Text(FormattingUtilities.formatBytes(self.databaseSize))
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text("In-Memory Cache")
                Spacer()
                Text("\(self.inMemoryCount) events")
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func eventsByKindSection(_ stats: NdbStat) -> some View {
        let nonEmptyKinds = stats.commonKinds.filter { !$0.value.isEmpty }
        let hasOtherKinds = !stats.otherKinds.isEmpty

        return Section("Events by Kind") {
            ForEach(Array(nonEmptyKinds), id: \.key.name) { kind, counts in
                KindStatRow(kind: kind, counts: counts)
            }

            if hasOtherKinds {
                HStack {
                    Text("Other Kinds")
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(stats.otherKinds.count)")
                            .font(.system(.body, design: .monospaced))
                        Text(FormattingUtilities.formatBytes(Int64(stats.otherKinds.totalSize)))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func databaseIndexesSection(_ stats: NdbStat) -> some View {
        let nonEmptyDbs = stats.databases.filter { !$0.value.isEmpty }

        return Section("Database Indexes") {
            ForEach(Array(nonEmptyDbs), id: \.key.name) { db, counts in
                DatabaseStatRow(database: db, counts: counts)
            }
        }
    }

    private func contentView(ndk: NDK) -> some View {
        List {
            self.contentSection
        }
        .navigationTitle("NostrDB Statistics")
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
            .task { await self.loadStats(ndk: ndk) }
            .refreshable { await self.loadStats(ndk: ndk) }
    }

    private func loadStats(ndk: NDK) async {
        self.isLoading = true
        self.error = nil

        guard let nostrDBCache = ndk.cache as? NDKNostrDBCache else {
            self.stats = nil
            self.isLoading = false
            return
        }

        self.stats = await nostrDBCache.getStats()
        self.databaseSize = await nostrDBCache.getDatabaseSize()
        self.cachePath = await nostrDBCache.getCachePath()
        self.inMemoryCount = await nostrDBCache.inMemoryEventCount
        self.isLoading = false
    }

    private func copyToClipboard(_ text: String) {
        #if os(iOS)
            UIPasteboard.general.string = text
        #else
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
        #endif
    }
}

// MARK: - KindStatRow

private struct KindStatRow: View {
    let kind: NdbCommonKind
    let counts: NdbStatCounts

    var body: some View {
        HStack {
            Text(self.kind.name)
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(self.counts.count)")
                    .font(.system(.body, design: .monospaced))
                Text(FormattingUtilities.formatBytes(Int64(self.counts.totalSize)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - DatabaseStatRow

private struct DatabaseStatRow: View {
    let database: NdbDatabase
    let counts: NdbStatCounts

    var body: some View {
        HStack {
            Text(self.database.name)
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(self.counts.count) entries")
                    .font(.system(.caption, design: .monospaced))
                HStack(spacing: 8) {
                    Text("K: \(FormattingUtilities.formatBytes(Int64(self.counts.keySize)))")
                    Text("V: \(FormattingUtilities.formatBytes(Int64(self.counts.valueSize)))")
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
        }
    }
}
