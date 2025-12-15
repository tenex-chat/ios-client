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
        // Combine common kinds and other kinds into a single sorted list
        var allKinds: [(kind: UInt64, counts: NdbStatCounts)] = []

        // Add common kinds
        for (kind, counts) in stats.commonKinds where !counts.isEmpty {
            allKinds.append((kind: UInt64(kind.rawValue), counts: counts))
        }

        // Add other kinds
        for (kind, counts) in stats.otherKinds.kinds where !counts.isEmpty {
            allKinds.append((kind: kind, counts: counts))
        }

        // Sort by kind number
        allKinds.sort { $0.kind < $1.kind }

        return Section("Events by Kind (\(allKinds.count) kinds)") {
            ForEach(allKinds, id: \.kind) { kind, counts in
                KindStatRow(kindNumber: kind, counts: counts)
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
    let kindNumber: UInt64
    let counts: NdbStatCounts

    var body: some View {
        HStack {
            Text("Kind \(self.kindNumber)")
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
