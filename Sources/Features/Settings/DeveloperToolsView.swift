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
                contentView(ndk: ndk)
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
            if isLoading {
                HStack {
                    ProgressView()
                    Text("Loading stats...")
                        .foregroundStyle(.secondary)
                }
            } else {
                QuickStatRow(label: "Connected Relays", value: "\(connectedRelayCount)/\(totalRelayCount)")
                if let pubkey = signerPubkey {
                    QuickStatRow(label: "Pubkey", value: String(pubkey.prefix(16)) + "...")
                }
            }
        }
    }

    private var inspectionToolsSection: some View {
        Section("Inspection Tools") {
            NavigationLink(destination: RelayMonitorView()) {
                ToolRow(
                    icon: "antenna.radiowaves.left.and.right",
                    title: "Relay Monitor",
                    subtitle: "Connection states and message counts",
                    color: .green
                )
            }

            NavigationLink(destination: NostrDBStatsView()) {
                ToolRow(
                    icon: "cylinder.split.1x2",
                    title: "NostrDB Statistics",
                    subtitle: "Cache analytics and storage metrics",
                    color: .blue
                )
            }

            NavigationLink(destination: SubscriptionMetricsView()) {
                ToolRow(
                    icon: "chart.bar.xaxis",
                    title: "Subscription Metrics",
                    subtitle: "Grouping efficiency and performance",
                    color: .purple
                )
            }
        }
    }

    private var infoSection: some View {
        Section("Info") {
            LabeledContent("NDK Log Level") {
                Text(logLevel.description)
                    .foregroundStyle(.secondary)
            }
            LabeledContent("Network Logging") {
                Text(isNetworkLoggingEnabled ? "Enabled" : "Disabled")
                    .foregroundStyle(isNetworkLoggingEnabled ? .green : .secondary)
            }
        }
    }

    private func contentView(ndk: NDK) -> some View {
        List {
            quickStatsSection
            inspectionToolsSection
            quickActionsSection(ndk: ndk)
            infoSection
        }
        .navigationTitle("Developer Tools")
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
            .task { await initialLoad(ndk: ndk) }
            .refreshable { await refreshStats(ndk: ndk) }
    }

    private func quickActionsSection(ndk: NDK) -> some View {
        Section("Quick Actions") {
            Button { Task { await refreshStats(ndk: ndk) } } label: {
                Label("Refresh Stats", systemImage: "arrow.clockwise")
            }
            Button { Task { await toggleLogLevel() } } label: {
                Label("Toggle Log Level (\(logLevel.description))", systemImage: "slider.horizontal.3")
            }
            Button { toggleNetworkLogging() } label: {
                Label(
                    isNetworkLoggingEnabled ? "Disable Network Logging" : "Enable Network Logging",
                    systemImage: isNetworkLoggingEnabled ? "wifi.slash" : "wifi"
                )
            }
            if let pubkey = signerPubkey {
                Button { copyPubkey(pubkey) } label: {
                    Label("Copy Pubkey", systemImage: "doc.on.doc")
                }
            }
        }
    }

    private func initialLoad(ndk: NDK) async {
        logLevel = NDKLogger.logLevel
        isNetworkLoggingEnabled = NDKLogger.logNetworkTraffic
        await refreshStats(ndk: ndk)
    }

    private func refreshStats(ndk: NDK) async {
        isLoading = true

        let relays = await ndk.relays
        totalRelayCount = relays.count

        var connected = 0
        for relay in relays {
            let state = await relay.connectionState
            if state == .connected || state == .authenticated {
                connected += 1
            }
        }
        connectedRelayCount = connected

        if let signer = ndk.signer {
            signerPubkey = try? await signer.pubkey
        }

        isLoading = false
    }

    private func toggleLogLevel() {
        let newLevel: NDKLogLevel = switch logLevel {
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
        logLevel = newLevel
    }

    private func toggleNetworkLogging() {
        isNetworkLoggingEnabled.toggle()
        NDKLogger.setLogNetworkTraffic(isNetworkLoggingEnabled)
    }

    private func copyPubkey(_ pubkey: String) {
        #if os(iOS)
            UIPasteboard.general.string = pubkey
        #else
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(pubkey, forType: .string)
        #endif
    }
}

// MARK: - QuickStatRow

private struct QuickStatRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
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
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(color)
                .cornerRadius(8)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
