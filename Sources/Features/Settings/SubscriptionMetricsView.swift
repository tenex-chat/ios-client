//
// SubscriptionMetricsView.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import NDKSwiftCore
import SwiftUI
import TENEXShared

// MARK: - SubscriptionMetricsView

/// View for displaying NDKSwift subscription grouping metrics and performance data
struct SubscriptionMetricsView: View {
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
    @State private var metrics: MetricsSnapshot?
    @State private var isLoading = true
    @State private var selectedRelayURL: String?

    @ViewBuilder private var contentSection: some View {
        if isLoading {
            loadingSection
        } else if let metrics {
            if metrics.totalSubscriptions == 0 {
                emptySection
            } else {
                overviewSection(metrics)
                efficiencySection(metrics)
                delayStatsSection(metrics)
                perRelaySection(metrics)
            }
        } else {
            emptySection
        }
    }

    private var loadingSection: some View {
        Section {
            HStack {
                ProgressView()
                Text("Loading metrics...")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var emptySection: some View {
        Section {
            VStack(spacing: 12) {
                Image(systemName: "chart.bar.xaxis")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                Text("No Subscription Activity")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Text("Subscription metrics will appear once subscriptions are created")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
        }
    }

    private func overviewSection(_ metrics: MetricsSnapshot) -> some View {
        Section("Overview") {
            MetricRow(label: "Total Subscriptions", value: "\(metrics.totalSubscriptions)")
            MetricRow(label: "Grouped Subscriptions", value: "\(metrics.groupedSubscriptions)", color: .green)
            MetricRow(label: "Non-Groupable", value: "\(metrics.nonGroupableSubscriptions)")
            MetricRow(label: "REQ Messages Sent", value: "\(metrics.totalReqMessages)")
            MetricRow(label: "REQ Messages Saved", value: "\(metrics.reqMessagesSaved)", color: .green)
        }
    }

    private func efficiencySection(_ metrics: MetricsSnapshot) -> some View {
        Section("Efficiency") {
            HStack {
                Text("Average Group Size")
                Spacer()
                Text(String(format: "%.2f", metrics.averageGroupSize))
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text("Grouping Efficiency")
                Spacer()
                Text(FormattingUtilities.formatPercentage(metrics.groupingEfficiency))
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(efficiencyColor(metrics.groupingEfficiency))
            }

            HStack {
                Text("Message Reduction")
                Spacer()
                Text(FormattingUtilities.formatPercentage(metrics.messageReduction))
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(efficiencyColor(metrics.messageReduction))
            }

            HStack {
                Text("Time Saved")
                Spacer()
                Text(FormattingUtilities.formatDuration(metrics.totalTimeSaved))
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.green)
            }
        }
    }

    private func delayStatsSection(_ metrics: MetricsSnapshot) -> some View {
        Section("Delay Statistics") {
            MetricRow(label: "Total Delays", value: "\(metrics.delayStatistics.totalDelays)")
            MetricRow(
                label: "Average Actual Delay",
                value: FormattingUtilities.formatDuration(metrics.delayStatistics.averageActualDelay)
            )
            MetricRow(
                label: "Average Configured Delay",
                value: FormattingUtilities.formatDuration(metrics.delayStatistics.averageConfiguredDelay)
            )
            MetricRow(label: "At Least Delays", value: "\(metrics.delayStatistics.atLeastCount)")
            MetricRow(label: "At Most Delays", value: "\(metrics.delayStatistics.atMostCount)")
        }
    }

    private func perRelaySection(_ metrics: MetricsSnapshot) -> some View {
        Section("Per-Relay Metrics (\(metrics.relayMetrics.count))") {
            if metrics.relayMetrics.isEmpty {
                Text("No per-relay metrics available")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            } else {
                ForEach(Array(metrics.relayMetrics.keys.sorted()), id: \.self) { relayURL in
                    if let relayMetric = metrics.relayMetrics[relayURL] {
                        RelayMetricRow(relayURL: relayURL, metrics: relayMetric)
                            .contentShape(Rectangle())
                            .onTapGesture { selectedRelayURL = relayURL }
                    }
                }
            }
        }
    }

    private func contentView(ndk: NDK) -> some View {
        List {
            contentSection
        }
        .navigationTitle("Subscription Metrics")
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
            .toolbar { toolbarContent(ndk: ndk) }
            .task { await loadMetrics(ndk: ndk) }
            .refreshable { await loadMetrics(ndk: ndk) }
            .sheet(item: $selectedRelayURL) { relayURL in
                NavigationStack {
                    RelayMetricsDetailView(
                        relayURL: relayURL,
                        metrics: metrics?.relayMetrics[relayURL]
                    )
                }
            }
    }

    @ToolbarContentBuilder private func toolbarContent(ndk: NDK) -> some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Menu {
                Button {
                    Task { await loadMetrics(ndk: ndk) }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }

                Button(role: .destructive) {
                    Task { await resetMetrics(ndk: ndk) }
                } label: {
                    Label("Reset Metrics", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
    }

    private func loadMetrics(ndk: NDK) async {
        isLoading = true
        metrics = await ndk.getSubscriptionMetrics()
        isLoading = false
    }

    private func resetMetrics(ndk: NDK) async {
        await ndk.resetSubscriptionMetrics()
        await loadMetrics(ndk: ndk)
    }

    private func efficiencyColor(_ efficiency: Double) -> Color {
        switch efficiency {
        case 0.8...:
            .green
        case 0.6 ..< 0.8:
            .blue
        case 0.4 ..< 0.6:
            .orange
        default:
            .red
        }
    }
}

// MARK: - RelayMetricRow

private struct RelayMetricRow: View {
    let relayURL: String
    let metrics: RelayMetrics

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(relayURL)
                .font(.system(.caption, design: .monospaced))
                .fontWeight(.medium)

            HStack(spacing: 12) {
                Text("\(metrics.totalReqMessages) REQs")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Text("Avg: \(String(format: "%.2f", metrics.averageGroupSize))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - RelayMetricsDetailView

private struct RelayMetricsDetailView: View {
    // MARK: Internal

    let relayURL: String
    let metrics: RelayMetrics?

    var body: some View {
        List {
            relaySection
            metricsSection
        }
        .navigationTitle("Relay Metrics")
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
    }

    // MARK: Private

    @Environment(\.dismiss) private var dismiss

    private var relaySection: some View {
        Section("Relay") {
            VStack(alignment: .leading, spacing: 4) {
                Text("URL")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(relayURL)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
            }
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder private var metricsSection: some View {
        if let metrics {
            Section("Metrics") {
                MetricRow(label: "Total REQ Messages", value: "\(metrics.totalReqMessages)")
                MetricRow(label: "Average Group Size", value: String(format: "%.2f", metrics.averageGroupSize))
            }
        } else {
            Section {
                Text("No metrics available")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - MetricRow

private struct MetricRow: View {
    let label: String
    let value: String
    var color: Color = .secondary

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(color)
        }
    }
}

// MARK: - String + @retroactive Identifiable

extension String: @retroactive Identifiable {
    public var id: String { self }
}
