//
// LogViewerView.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import NDKSwiftCore
import SwiftUI
import TENEXShared

// MARK: - Log Level Styling

private func colorForLogLevel(_ level: NDKLogLevel, inMessage: Bool = false) -> Color {
    switch level {
    case .error:
        .red
    case .warning:
        .orange
    case .info:
        inMessage ? .primary : .blue
    case .debug:
        inMessage ? .secondary : .gray
    case .trace,
         .off:
        .secondary
    }
}

private func iconForLogLevel(_ level: NDKLogLevel) -> String {
    switch level {
    case .error:
        "xmark.circle.fill"
    case .warning:
        "exclamationmark.triangle.fill"
    case .info:
        "info.circle.fill"
    case .debug:
        "ladybug.fill"
    case .trace:
        "ant.fill"
    case .off:
        "nosign"
    }
}

// MARK: - LogViewerView

/// View for displaying real-time NDK logs
struct LogViewerView: View {
    // MARK: Internal

    var body: some View {
        VStack(spacing: 0) {
            filterBar
            searchBar
            Divider()
            contentView
        }
        .navigationTitle("Log Viewer")
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
            .toolbar { toolbarContent }
            .task { await initialLoad() }
            .task(id: isLive) { await pollForUpdates() }
            .refreshable { await loadEntries() }
    }

    // MARK: Private

    @State private var entries: [NDKLogEntry] = []
    @State private var selectedLevel: NDKLogLevel?
    @State private var selectedCategory: NDKLogCategory?
    @State private var searchText = ""
    @State private var isLive = true
    @State private var isLoading = true

    @ToolbarContentBuilder private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Menu {
                Button { toggleLogLevel() } label: {
                    Label("Log Level: \(NDKLogger.logLevel.description)", systemImage: "slider.horizontal.3")
                }
                Divider()
                Button { copyLogs() } label: {
                    Label("Copy Logs", systemImage: "doc.on.doc")
                }
                Button(role: .destructive) {
                    Task {
                        await NDKLogBuffer.shared.clearLogs()
                        await loadEntries()
                    }
                } label: {
                    Label("Clear Logs", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
    }

    private var filteredEntries: [NDKLogEntry] {
        var result = entries
        if let level = selectedLevel {
            result = result.filter { $0.level == level }
        }
        if let category = selectedCategory {
            result = result.filter { $0.category == category }
        }
        if !searchText.isEmpty {
            result = result.filter { $0.message.localizedCaseInsensitiveContains(searchText) }
        }
        return result
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                levelFilter
                categoryFilter
                liveToggle
                Spacer()
                clearButton
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
        #if os(iOS)
            .background(Color(.systemGroupedBackground))
        #else
            .background(Color(nsColor: .windowBackgroundColor))
        #endif
    }

    private var levelFilter: some View {
        Menu {
            Button("All Levels") { selectedLevel = nil }
            Divider()
            ForEach([NDKLogLevel.error, .warning, .info, .debug, .trace], id: \.self) { level in
                Button {
                    selectedLevel = level
                } label: {
                    Label(level.description, systemImage: iconForLogLevel(level))
                }
            }
        } label: {
            FilterChip(
                label: selectedLevel?.description ?? "Level",
                isActive: selectedLevel != nil,
                color: selectedLevel.map { colorForLogLevel($0) } ?? .secondary
            )
        }
    }

    private var categoryFilter: some View {
        Menu {
            Button("All Categories") { selectedCategory = nil }
            Divider()
            ForEach(NDKLogCategory.allCases, id: \.self) { category in
                Button(category.rawValue) { selectedCategory = category }
            }
        } label: {
            FilterChip(
                label: selectedCategory?.rawValue ?? "Category",
                isActive: selectedCategory != nil,
                color: .blue
            )
        }
    }

    private var liveToggle: some View {
        Button { isLive.toggle() } label: {
            FilterChip(
                label: isLive ? "Live" : "Paused",
                isActive: isLive,
                color: isLive ? .green : .orange
            )
        }
    }

    private var clearButton: some View {
        Button {
            Task {
                await NDKLogBuffer.shared.clearLogs()
                await loadEntries()
            }
        } label: {
            Image(systemName: "trash")
                .foregroundStyle(.red)
        }
    }

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search logs...", text: $searchText)
                .textFieldStyle(.plain)
            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(8)
        #if os(iOS)
            .background(Color(.secondarySystemGroupedBackground))
        #else
            .background(Color(nsColor: .controlBackgroundColor))
        #endif
            .cornerRadius(8)
            .padding(.horizontal)
            .padding(.bottom, 8)
    }

    @ViewBuilder private var contentView: some View {
        if isLoading {
            loadingView
        } else if filteredEntries.isEmpty {
            emptyView
        } else {
            logList
        }
    }

    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView("Loading logs...")
            Spacer()
        }
    }

    private var emptyView: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "doc.text")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("No log entries")
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    private var logList: some View {
        ScrollViewReader { proxy in
            List {
                ForEach(filteredEntries) { entry in
                    LogEntryRow(entry: entry)
                        .id(entry.id)
                }
            }
            .listStyle(.plain)
            .onChange(of: filteredEntries.count) { _, _ in
                if isLive, let lastEntry = filteredEntries.last {
                    withAnimation { proxy.scrollTo(lastEntry.id, anchor: .bottom) }
                }
            }
        }
    }

    private func initialLoad() async {
        await loadEntries()
        isLoading = false
    }

    private func pollForUpdates() async {
        guard isLive else {
            return
        }
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(1))
            await loadEntries()
        }
    }

    private func loadEntries() async {
        entries = await NDKLogBuffer.shared.getEntries()
    }

    private func toggleLogLevel() {
        switch NDKLogger.logLevel {
        case .info:
            NDKLogger.logLevel = .debug
        case .debug:
            NDKLogger.logLevel = .trace
        case .trace:
            NDKLogger.logLevel = .info
        default:
            NDKLogger.logLevel = .info
        }
    }

    private func copyLogs() {
        let logText = filteredEntries
            .map { entry in
                "[\(FormattingUtilities.timestamp(entry.timestamp))] [\(entry.level)] [\(entry.category.rawValue)] \(entry.message)"
            }
            .joined(separator: "\n")
        #if os(iOS)
            UIPasteboard.general.string = logText
        #else
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(logText, forType: .string)
        #endif
    }
}

// MARK: - FilterChip

private struct FilterChip: View {
    // MARK: Internal

    let label: String
    let isActive: Bool
    let color: Color

    var body: some View {
        Text(label)
            .font(.caption)
            .fontWeight(isActive ? .semibold : .regular)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(backgroundColor)
            .foregroundStyle(isActive ? color : .primary)
            .cornerRadius(16)
    }

    // MARK: Private

    private var backgroundColor: Color {
        if isActive {
            return color.opacity(0.2)
        }
        #if os(iOS)
            return Color(.tertiarySystemGroupedBackground)
        #else
            return Color(nsColor: .controlBackgroundColor)
        #endif
    }
}

// MARK: - LogEntryRow

private struct LogEntryRow: View {
    // MARK: Internal

    let entry: NDKLogEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            headerRow
            messageText
        }
        .padding(.vertical, 4)
    }

    // MARK: Private

    private var categoryBackground: Color {
        #if os(iOS)
            Color(.tertiarySystemGroupedBackground)
        #else
            Color(nsColor: .controlBackgroundColor)
        #endif
    }

    private var headerRow: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(colorForLogLevel(entry.level, inMessage: true))
                .frame(width: 8, height: 8)
            Text(FormattingUtilities.timestamp(entry.timestamp))
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.secondary)
            categoryBadge
            Spacer()
        }
    }

    private var categoryBadge: some View {
        Text(entry.category.rawValue)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(categoryBackground)
            .cornerRadius(4)
    }

    private var messageText: some View {
        Text(entry.message)
            .font(.system(.caption, design: .monospaced))
            .foregroundStyle(colorForLogLevel(entry.level, inMessage: true))
            .textSelection(.enabled)
    }
}
