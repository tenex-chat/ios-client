//
// DeveloperToolsView.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import NDKSwiftCore
import SwiftUI

// MARK: - DeveloperToolsView

/// Central hub for developer debugging tools
struct DeveloperToolsView: View {
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
    @State private var isLoading = true
    @State private var totalRelayCount = 0
    @State private var connectedRelayCount = 0
    @State private var signerPubkey: String?
    @State private var isNetworkLoggingEnabled = false
    @State private var logLevel: NDKLogLevel = .info

    private var quickStatsSection: some View {
        Section("Quick Stats") {
            if self.isLoading {
                HStack {
                    ProgressView()
                    Text("Loading stats...")
                        .foregroundStyle(.secondary)
                }
            } else {
                QuickStatRow(label: "Connected Relays", value: "\(self.connectedRelayCount)/\(self.totalRelayCount)")
                if let pubkey = signerPubkey {
                    QuickStatRow(label: "Pubkey", value: String(pubkey.prefix(16)) + "...")
                }
            }
        }
    }

    private var inspectionToolsSection: some View {
        Section("Inspection Tools") {
            self.relayMonitorLink
            self.nostrDBStatsLink
            self.subscriptionMetricsLink
            self.projectStatusLink
        }
    }

    private var relayMonitorLink: some View {
        NavigationLink(destination: RelayMonitorView()) {
            ToolRow(
                icon: "antenna.radiowaves.left.and.right",
                title: "Relay Monitor",
                subtitle: "Connection states and message counts",
                color: .green
            )
        }
    }

    private var nostrDBStatsLink: some View {
        NavigationLink(destination: NostrDBStatsView()) {
            ToolRow(
                icon: "cylinder.split.1x2",
                title: "NostrDB Statistics",
                subtitle: "Cache analytics and storage metrics",
                color: .blue
            )
        }
    }

    private var subscriptionMetricsLink: some View {
        NavigationLink(destination: SubscriptionMetricsView()) {
            ToolRow(
                icon: "chart.bar.xaxis",
                title: "Subscription Metrics",
                subtitle: "Grouping efficiency and performance",
                color: .purple
            )
        }
    }

    private var projectStatusLink: some View {
        NavigationLink(destination: ProjectStatusDebugView()) {
            ToolRow(
                icon: "server.rack",
                title: "Project Status",
                subtitle: "Online agents and backend status",
                color: .orange
            )
        }
    }

    private var infoSection: some View {
        Section("Info") {
            LabeledContent("NDK Log Level") {
                Text(self.logLevel.description)
                    .foregroundStyle(.secondary)
            }
            LabeledContent("Network Logging") {
                Text(self.isNetworkLoggingEnabled ? "Enabled" : "Disabled")
                    .foregroundStyle(self.isNetworkLoggingEnabled ? .green : .secondary)
            }
        }
    }

    private func contentView(ndk: NDK) -> some View {
        List {
            self.quickStatsSection
            self.inspectionToolsSection
            self.quickActionsSection(ndk: ndk)
            self.infoSection
        }
        .navigationTitle("Developer Tools")
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
            .task { await self.initialLoad(ndk: ndk) }
            .refreshable { await self.refreshStats(ndk: ndk) }
    }

    private func quickActionsSection(ndk: NDK) -> some View {
        Section("Quick Actions") {
            Button { Task { await self.refreshStats(ndk: ndk) } } label: {
                Label("Refresh Stats", systemImage: "arrow.clockwise")
            }
            Button { Task { await self.toggleLogLevel() } } label: {
                Label("Toggle Log Level (\(self.logLevel.description))", systemImage: "slider.horizontal.3")
            }
            Button { self.toggleNetworkLogging() } label: {
                Label(
                    self.isNetworkLoggingEnabled ? "Disable Network Logging" : "Enable Network Logging",
                    systemImage: self.isNetworkLoggingEnabled ? "wifi.slash" : "wifi"
                )
            }
        }
    }

    private func initialLoad(ndk: NDK) async {
        self.logLevel = NDKLogger.logLevel
        self.isNetworkLoggingEnabled = NDKLogger.logNetworkTraffic
        await self.refreshStats(ndk: ndk)
    }

    private func refreshStats(ndk: NDK) async {
        self.isLoading = true

        let relays = await ndk.relays
        self.totalRelayCount = relays.count

        var connected = 0
        for relay in relays {
            let state = await relay.connectionState
            if state == .connected || state == .authenticated {
                connected += 1
            }
        }
        self.connectedRelayCount = connected

        if let signer = ndk.signer {
            self.signerPubkey = try? await signer.pubkey
        }

        self.isLoading = false
    }

    private func toggleLogLevel() {
        let newLevel: NDKLogLevel = switch self.logLevel {
        case .info:
            .debug
        case .debug:
            .trace
        case .trace:
            .info
        default:
            .info
        }
        NDKLogger.setLogLevel(newLevel)
        self.logLevel = newLevel
    }

    private func toggleNetworkLogging() {
        self.isNetworkLoggingEnabled.toggle()
        NDKLogger.setLogNetworkTraffic(self.isNetworkLoggingEnabled)
    }
}

// MARK: - QuickStatRow

private struct QuickStatRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(self.label)
            Spacer()
            Text(self.value)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - ToolRow

private struct ToolRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: self.icon)
                .font(.callout)
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(self.color)
                .cornerRadius(8)

            VStack(alignment: .leading, spacing: 2) {
                Text(self.title)
                    .font(.body)
                Text(self.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
