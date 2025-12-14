//
// NostrDBStatsView.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import NDKSwiftCore
import NDKSwiftNostrDB
import SwiftUI
import TENEXShared

// MARK: - NdbStatCounts + Helpers

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
                contentView(ndk: ndk)
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
        if isLoading {
            loadingSection
        } else if let error {
            errorSection(error)
        } else if let stats {
            overviewSection(stats)
            eventsByKindSection(stats)
            databaseIndexesSection(stats)
            storageDetailsSection
        } else {
            notAvailableSection
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
                    copyToClipboard(cachePath)
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
                Text(FormattingUtilities.formatBytes(databaseSize))
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text("In-Memory Cache")
                Spacer()
                Text("\(inMemoryCount) events")
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func eventsByKindSection(_ stats: NdbStat) -> some View {
        let hasOtherKinds = !stats.otherKinds.isEmpty

        return Section("Events by Kind") {
            ForEach(NdbCommonKind.allCases, id: \.self) { kind in
                if let counts = stats.commonKinds[kind], !counts.isEmpty {
                    KindStatRow(kind: kind, counts: counts)
                }
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
        Section("Database Indexes") {
            ForEach(NdbDatabase.allCases, id: \.self) { db in
                if let counts = stats.databases[db], !counts.isEmpty {
                    DatabaseStatRow(database: db, counts: counts)
                }
            }
        }
    }

    private func contentView(ndk: NDK) -> some View {
        List {
            contentSection
        }
        .navigationTitle("NostrDB Statistics")
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
            .task { await loadStats(ndk: ndk) }
            .refreshable { await loadStats(ndk: ndk) }
    }

    private func loadStats(ndk: NDK) async {
        isLoading = true
        error = nil

        guard let nostrDBCache = ndk.cache as? NDKNostrDBCache else {
            stats = nil
            isLoading = false
            return
        }

        stats = await nostrDBCache.getStats()
        databaseSize = await nostrDBCache.getDatabaseSize()
        cachePath = await nostrDBCache.getCachePath()
        inMemoryCount = await nostrDBCache.inMemoryEventCount
        isLoading = false
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
            Text(kind.name)
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(counts.count)")
                    .font(.system(.body, design: .monospaced))
                Text(FormattingUtilities.formatBytes(Int64(counts.totalSize)))
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
            Text(database.name)
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(counts.count) entries")
                    .font(.system(.caption, design: .monospaced))
                HStack(spacing: 8) {
                    Text("K: \(FormattingUtilities.formatBytes(Int64(counts.keySize)))")
                    Text("V: \(FormattingUtilities.formatBytes(Int64(counts.valueSize)))")
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
        }
    }
}
