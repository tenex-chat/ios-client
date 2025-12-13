//
// RelayMonitorView.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import NDKSwiftCore
import SwiftUI
import TENEXShared

// MARK: - RelayMonitorView

/// View for monitoring relay connectivity and statistics
struct RelayMonitorView: View {
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
    @State private var relays: [NDKRelay] = []
    @State private var relayStates: [RelayURL: NDKRelay.State] = [:]
    @State private var selectedRelay: NDKRelay?
    @State private var isLoading = true

    private var sortedRelays: [NDKRelay] {
        relays.sorted { relay1, relay2 in
            let state1 = relayStates[relay1.url]?.connectionState
            let state2 = relayStates[relay2.url]?.connectionState

            let isConnected1 = state1 == .connected || state1 == .authenticated
            let isConnected2 = state2 == .connected || state2 == .authenticated

            if isConnected1, !isConnected2 {
                return true
            }
            if !isConnected1, isConnected2 {
                return false
            }
            return relay1.url < relay2.url
        }
    }

    private var connectedCount: Int {
        relayStates.values.count { state in
            state.connectionState == .connected || state.connectionState == .authenticated
        }
    }

    private var disconnectedCount: Int {
        relays.count - connectedCount
    }

    @ViewBuilder private var contentSection: some View {
        if isLoading {
            loadingSection
        } else if relays.isEmpty {
            emptySection
        } else {
            summarySection
            relayListSection
        }
    }

    private var loadingSection: some View {
        Section {
            HStack {
                ProgressView()
                Text("Loading relays...")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var emptySection: some View {
        Section {
            VStack(spacing: 12) {
                Image(systemName: "antenna.radiowaves.left.and.right.slash")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                Text("No relays configured")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
        }
    }

    private var summarySection: some View {
        Section("Summary") {
            HStack {
                Text("Total Relays")
                Spacer()
                Text("\(relays.count)")
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text("Connected")
                Spacer()
                Text("\(connectedCount)")
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.green)
            }

            HStack {
                Text("Disconnected")
                Spacer()
                Text("\(disconnectedCount)")
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(disconnectedCount > 0 ? .red : .secondary)
            }
        }
    }

    private var relayListSection: some View {
        Section("Relays") {
            ForEach(sortedRelays, id: \.url) { relay in
                RelayMonitorRowView(relay: relay, state: relayStates[relay.url])
                    .contentShape(Rectangle())
                    .onTapGesture { selectedRelay = relay }
            }
        }
    }

    private func contentView(ndk: NDK) -> some View {
        List {
            contentSection
        }
        .navigationTitle("Relay Monitor")
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
            .toolbar { toolbarContent(ndk: ndk) }
            .task { await initialLoad(ndk: ndk) }
            .refreshable { await loadRelayStates(ndk: ndk) }
            .sheet(item: $selectedRelay) { relay in
                NavigationStack {
                    RelayDetailView(relay: relay, state: relayStates[relay.url])
                }
            }
    }

    @ToolbarContentBuilder private func toolbarContent(ndk _: NDK) -> some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button { Task { await reconnectAll() } } label: {
                Image(systemName: "arrow.clockwise")
            }
        }
    }

    private func initialLoad(ndk: NDK) async {
        await loadRelayStates(ndk: ndk)
        isLoading = false

        for relay in relays {
            Task {
                for await state in relay.stateStream {
                    await MainActor.run { relayStates[relay.url] = state }
                }
            }
        }
    }

    private func loadRelayStates(ndk: NDK) async {
        relays = await ndk.relays
        for relay in relays {
            let state = await NDKRelay.State(
                connectionState: relay.connectionState,
                stats: relay.stats,
                info: relay.info,
                activeSubscriptions: relay.activeSubscriptions
            )
            await MainActor.run { relayStates[relay.url] = state }
        }
    }

    private func reconnectAll() async {
        for relay in relays {
            let state = await relay.connectionState
            if state != .connected, state != .authenticated, state != .connecting {
                try? await relay.connect()
            }
        }
    }
}

// MARK: - RelayMonitorRowView

private struct RelayMonitorRowView: View {
    // MARK: Internal

    let relay: NDKRelay
    let state: NDKRelay.State?

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(statusColor)
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 4) {
                Text(relay.url)
                    .font(.system(.body, design: .monospaced))
                    .lineLimit(1)
                statsRow
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }

    // MARK: Private

    private var statusColor: Color {
        guard let connectionState = state?.connectionState else {
            return .gray
        }

        switch connectionState {
        case .connected,
             .authenticated:
            return .green
        case .connecting,
             .authenticating:
            return .yellow
        case .disconnected,
             .disconnecting:
            return .gray
        case .authRequired:
            return .orange
        case .failed:
            return .red
        }
    }

    @ViewBuilder private var statsRow: some View {
        if let stats = state?.stats {
            HStack(spacing: 12) {
                Label("\(stats.messagesReceived)", systemImage: "arrow.down")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Label("\(stats.messagesSent)", systemImage: "arrow.up")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                if let latency = stats.latency {
                    Label(String(format: "%.0fms", latency * 1000), systemImage: "timer")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: - RelayDetailView

private struct RelayDetailView: View {
    // MARK: Internal

    let relay: NDKRelay
    let state: NDKRelay.State?

    var body: some View {
        List {
            connectionSection
            statisticsSection
            signatureSection
            relayInfoSection
            subscriptionsSection
            actionsSection
        }
        .navigationTitle("Relay Details")
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(item: $selectedSubscription) { subscription in
                NavigationStack {
                    SubscriptionDetailView(
                        relay: relay,
                        subscription: subscription
                    )
                }
            }
    }

    // MARK: Private

    @Environment(\.dismiss) private var dismiss
    @State private var isReconnecting = false
    @State private var selectedSubscription: NDKRelaySubscriptionInfo?

    private var statusColor: Color {
        guard let connectionState = state?.connectionState else {
            return .gray
        }

        switch connectionState {
        case .connected,
             .authenticated:
            return .green
        case .connecting,
             .authenticating:
            return .yellow
        case .disconnected,
             .disconnecting:
            return .gray
        case .authRequired:
            return .orange
        case .failed:
            return .red
        }
    }

    private var statusText: String {
        guard let connectionState = state?.connectionState else {
            return "Unknown"
        }

        switch connectionState {
        case .connected:
            return "Connected"
        case .authenticated:
            return "Authenticated"
        case .connecting:
            return "Connecting..."
        case .authenticating:
            return "Authenticating..."
        case .disconnected:
            return "Disconnected"
        case .disconnecting:
            return "Disconnecting..."
        case .authRequired:
            return "Auth Required"
        case let .failed(message):
            return "Failed: \(message)"
        }
    }

    private var connectionSection: some View {
        Section("Connection") {
            LabeledContent("Status") {
                HStack(spacing: 6) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 8, height: 8)
                    Text(statusText)
                        .foregroundStyle(statusColor)
                }
            }

            if let connectedAt = state?.stats.connectedAt {
                LabeledContent("Connected At") {
                    Text(FormattingUtilities.shortDateTime(connectedAt))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if let lastMessage = state?.stats.lastMessageAt {
                LabeledContent("Last Activity") {
                    Text(FormattingUtilities.relative(lastMessage))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if let latency = state?.stats.latency {
                LabeledContent("Latency") {
                    Text(String(format: "%.0fms", latency * 1000))
                        .font(.system(.body, design: .monospaced))
                }
            }
        }
    }

    private var statisticsSection: some View {
        Section("Statistics") {
            LabeledContent("Messages Received") {
                Text("\(state?.stats.messagesReceived ?? 0)")
                    .font(.system(.body, design: .monospaced))
            }

            LabeledContent("Messages Sent") {
                Text("\(state?.stats.messagesSent ?? 0)")
                    .font(.system(.body, design: .monospaced))
            }

            LabeledContent("Bytes Received") {
                Text(FormattingUtilities.formatBytes(Int64(state?.stats.bytesReceived ?? 0)))
                    .font(.system(.body, design: .monospaced))
            }

            LabeledContent("Bytes Sent") {
                Text(FormattingUtilities.formatBytes(Int64(state?.stats.bytesSent ?? 0)))
                    .font(.system(.body, design: .monospaced))
            }

            LabeledContent("Connection Attempts") {
                Text("\(state?.stats.connectionAttempts ?? 0)")
                    .font(.system(.body, design: .monospaced))
            }

            LabeledContent("Successful Connections") {
                Text("\(state?.stats.successfulConnections ?? 0)")
                    .font(.system(.body, design: .monospaced))
            }
        }
    }

    @ViewBuilder private var signatureSection: some View {
        if let sigStats = state?.stats.signatureStats {
            Section("Signature Verification") {
                LabeledContent("Validated") {
                    Text("\(sigStats.validatedCount)")
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.green)
                }

                LabeledContent("Skipped (Sampling)") {
                    Text("\(sigStats.nonValidatedCount)")
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.secondary)
                }

                LabeledContent("Validation Ratio") {
                    Text(String(format: "%.0f%%", sigStats.currentValidationRatio * 100))
                        .font(.system(.body, design: .monospaced))
                }
            }
        }
    }

    @ViewBuilder private var relayInfoSection: some View {
        if let info = state?.info {
            Section("Relay Information (NIP-11)") {
                relayInfoContent(info)
            }
        }
    }

    @ViewBuilder private var subscriptionsSection: some View {
        if let subscriptions = state?.activeSubscriptions, !subscriptions.isEmpty {
            Section("Active Subscriptions (\(subscriptions.count))") {
                ForEach(subscriptions, id: \.id) { sub in
                    SubscriptionRow(sub: sub)
                        .contentShape(Rectangle())
                        .onTapGesture { selectedSubscription = sub }
                }
            }
        }
    }

    private var actionsSection: some View {
        Section {
            Button {
                Task {
                    isReconnecting = true
                    await relay.disconnect()
                    try? await relay.connect()
                    isReconnecting = false
                }
            } label: {
                HStack {
                    Label("Reconnect", systemImage: "arrow.clockwise")
                    if isReconnecting {
                        Spacer()
                        ProgressView()
                    }
                }
            }
            .disabled(isReconnecting)

            Button { copyURL() } label: {
                Label("Copy URL", systemImage: "doc.on.doc")
            }
        }
    }

    @ViewBuilder
    private func relayInfoContent(_ info: NDKRelayInformation) -> some View {
        if let name = info.name {
            LabeledContent("Name") { Text(name) }
        }

        if let description = info.description {
            VStack(alignment: .leading, spacing: 4) {
                Text("Description")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(description)
                    .font(.caption)
            }
            .padding(.vertical, 4)
        }

        if let software = info.software {
            LabeledContent("Software") { Text(software).font(.caption) }
        }

        if let version = info.version {
            LabeledContent("Version") {
                Text(version).font(.system(.caption, design: .monospaced))
            }
        }

        if let nips = info.supportedNips, !nips.isEmpty {
            LabeledContent("Supported NIPs") {
                Text(nips.map { "\($0)" }.joined(separator: ", "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }

        if let contact = info.contact {
            LabeledContent("Contact") { Text(contact).font(.caption) }
        }
    }

    private func copyURL() {
        #if os(iOS)
            UIPasteboard.general.string = relay.url
        #else
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(relay.url, forType: .string)
        #endif
    }
}

// MARK: - SubscriptionRow

private struct SubscriptionRow: View {
    let sub: NDKRelaySubscriptionInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(sub.id)
                .font(.system(.caption, design: .monospaced))
                .fontWeight(.medium)

            HStack(spacing: 12) {
                Text("\(sub.eventCount) events")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Text("\(sub.filters.count) filters")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                if let lastEvent = sub.lastEventAt {
                    Text(FormattingUtilities.relative(lastEvent))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }
}
