//
// NetworkTrafficView.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import NDKSwift
import SwiftUI

// MARK: - NetworkTrafficView

/// View for monitoring raw Nostr protocol messages
struct NetworkTrafficView: View {
    // MARK: Internal

    var body: some View {
        VStack(spacing: 0) {
            loggingToggle
            filterBar
            Divider()
            contentView
        }
        .navigationTitle("Network Traffic")
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
            .task { await initialLoad() }
            .task(id: isLive) { await pollForUpdates() }
            .refreshable { await loadMessages() }
            .sheet(item: $selectedMessage) { message in
                NavigationStack {
                    NetworkMessageDetailView(message: message)
                }
            }
    }

    // MARK: Private

    private let messageTypes = ["REQ", "EVENT", "EOSE", "OK", "NOTICE", "AUTH", "CLOSE", "COUNT"]

    @State private var messages: [NDKNetworkMessage] = []
    @State private var selectedDirection: NDKNetworkMessage.Direction?
    @State private var selectedMessageType: String?
    @State private var isLive = true
    @State private var isLoading = true
    @State private var selectedMessage: NDKNetworkMessage?

    private var loggingToggle: some View {
        HStack {
            Text("Network Logging")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Toggle("", isOn: Binding(
                get: { NDKLogger.logNetworkTraffic },
                set: { NDKLogger.logNetworkTraffic = $0 }
            ))
            .labelsHidden()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        #if os(iOS)
            .background(Color(.systemGroupedBackground))
        #else
            .background(Color(nsColor: .windowBackgroundColor))
        #endif
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                directionFilter
                typeFilter
                liveToggle
                Spacer()
                clearButton
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
    }

    private var directionFilter: some View {
        Menu {
            Button("All Directions") { selectedDirection = nil }
            Divider()
            Button { selectedDirection = .inbound } label: {
                Label("Inbound", systemImage: "arrow.down")
            }
            Button { selectedDirection = .outbound } label: {
                Label("Outbound", systemImage: "arrow.up")
            }
        } label: {
            TrafficFilterChip(
                label: selectedDirection?.rawValue ?? "Direction",
                isActive: selectedDirection != nil,
                color: directionFilterColor
            )
        }
    }

    private var directionFilterColor: Color {
        guard let dir = selectedDirection else {
            return .secondary
        }
        return dir == .inbound ? .green : .blue
    }

    private var typeFilter: some View {
        Menu {
            Button("All Types") { selectedMessageType = nil }
            Divider()
            ForEach(messageTypes, id: \.self) { type in
                Button(type) { selectedMessageType = type }
            }
        } label: {
            TrafficFilterChip(
                label: selectedMessageType ?? "Type",
                isActive: selectedMessageType != nil,
                color: .purple
            )
        }
    }

    private var liveToggle: some View {
        Button { isLive.toggle() } label: {
            TrafficFilterChip(
                label: isLive ? "Live" : "Paused",
                isActive: isLive,
                color: isLive ? .green : .orange
            )
        }
    }

    private var clearButton: some View {
        Button {
            Task {
                await NDKLogBuffer.shared.clearNetworkMessages()
                await loadMessages()
            }
        } label: {
            Image(systemName: "trash")
                .foregroundStyle(.red)
        }
    }

    @ViewBuilder private var contentView: some View {
        if !NDKLogger.logNetworkTraffic {
            disabledView
        } else if isLoading {
            loadingView
        } else if filteredMessages.isEmpty {
            emptyView
        } else {
            messageList
        }
    }

    private var disabledView: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "wifi.slash")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Network logging is disabled")
                .foregroundStyle(.secondary)
            Text("Enable it above to capture traffic")
                .font(.caption)
                .foregroundStyle(.tertiary)
            Spacer()
        }
    }

    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView("Loading...")
            Spacer()
        }
    }

    private var emptyView: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "arrow.left.arrow.right")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No network messages")
                .foregroundStyle(.secondary)
            Text("Messages will appear here as they're sent/received")
                .font(.caption)
                .foregroundStyle(.tertiary)
            Spacer()
        }
    }

    private var messageList: some View {
        List {
            ForEach(filteredMessages) { message in
                NetworkMessageRow(message: message)
                    .contentShape(Rectangle())
                    .onTapGesture { selectedMessage = message }
            }
        }
        .listStyle(.plain)
    }

    private var filteredMessages: [NDKNetworkMessage] {
        var result = messages
        if let direction = selectedDirection {
            result = result.filter { $0.direction == direction }
        }
        if let type = selectedMessageType {
            result = result.filter { $0.messageType == type }
        }
        return result
    }

    private func initialLoad() async {
        await loadMessages()
        isLoading = false
    }

    private func pollForUpdates() async {
        guard isLive else {
            return
        }
        while !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(500))
            await loadMessages()
        }
    }

    private func loadMessages() async {
        messages = await NDKLogBuffer.shared.getNetworkMessages()
    }
}

// MARK: - TrafficFilterChip

private struct TrafficFilterChip: View {
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
        #if os(iOS)
            isActive ? color.opacity(0.2) : Color(.tertiarySystemGroupedBackground)
        #else
            isActive ? color.opacity(0.2) : Color(nsColor: .controlBackgroundColor)
        #endif
    }
}

// MARK: - NetworkMessageRow

private struct NetworkMessageRow: View {
    // MARK: Internal

    let message: NDKNetworkMessage

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            headerRow
            relayText
            previewText
        }
        .padding(.vertical, 4)
    }

    // MARK: Private

    private var typeColor: Color {
        switch message.messageType {
        case "EVENT":
            .blue
        case "REQ":
            .purple
        case "EOSE":
            .green
        case "OK":
            .teal
        case "NOTICE":
            .orange
        case "AUTH":
            .red
        case "CLOSE":
            .gray
        case "COUNT":
            .yellow
        default:
            .secondary
        }
    }

    private var headerRow: some View {
        HStack(spacing: 8) {
            directionIcon
            typeBadge
            timestampText
            Spacer()
        }
    }

    private var directionIcon: some View {
        Image(systemName: message.direction == .inbound ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
            .foregroundStyle(message.direction == .inbound ? .green : .blue)
            .font(.caption)
    }

    private var typeBadge: some View {
        Text(message.messageType)
            .font(.caption2)
            .fontWeight(.bold)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(typeColor.opacity(0.2))
            .foregroundStyle(typeColor)
            .cornerRadius(4)
    }

    private var timestampText: some View {
        Text(formatTimestamp(message.timestamp))
            .font(.system(.caption2, design: .monospaced))
            .foregroundStyle(.secondary)
    }

    private var relayText: some View {
        Text(message.relay)
            .font(.system(.caption2, design: .monospaced))
            .foregroundStyle(.secondary)
    }

    private var previewText: some View {
        let preview = message.raw.prefix(100)
        let suffix = message.raw.count > 100 ? "..." : ""
        return Text(preview + suffix)
            .font(.system(.caption, design: .monospaced))
            .lineLimit(2)
            .foregroundStyle(.primary)
    }

    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: date)
    }
}

// MARK: - NetworkMessageDetailView

private struct NetworkMessageDetailView: View {
    // MARK: Internal

    let message: NDKNetworkMessage

    var body: some View {
        List {
            infoSection
            rawSection
            formattedSection
            actionsSection
        }
        .navigationTitle("Message Details")
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

    private var infoSection: some View {
        Section("Message Info") {
            LabeledContent("Direction") {
                HStack(spacing: 4) {
                    Image(systemName: message.direction == .inbound ? "arrow.down" : "arrow.up")
                    Text(message.direction == .inbound ? "Inbound" : "Outbound")
                }
                .foregroundStyle(message.direction == .inbound ? .green : .blue)
            }
            LabeledContent("Type") {
                Text(message.messageType)
                    .font(.system(.body, design: .monospaced))
                    .fontWeight(.semibold)
            }
            LabeledContent("Relay") {
                Text(message.relay)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
            }
            LabeledContent("Timestamp") {
                Text(formatFullTimestamp(message.timestamp))
                    .font(.caption)
            }
        }
    }

    private var rawSection: some View {
        Section("Raw Message") {
            Text(message.raw)
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)
        }
    }

    @ViewBuilder private var formattedSection: some View {
        if let prettyJSON = prettyPrintJSON(message.raw) {
            Section("Formatted JSON") {
                Text(prettyJSON)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
            }
        }
    }

    private var actionsSection: some View {
        Section {
            Button { copyToClipboard(message.raw) } label: {
                Label("Copy Raw Message", systemImage: "doc.on.doc")
            }
            if let prettyJSON = prettyPrintJSON(message.raw) {
                Button { copyToClipboard(prettyJSON) } label: {
                    Label("Copy Formatted JSON", systemImage: "doc.on.doc")
                }
            }
        }
    }

    private func copyToClipboard(_ text: String) {
        #if os(iOS)
            UIPasteboard.general.string = text
        #else
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
        #endif
    }

    private func formatFullTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }

    private func prettyPrintJSON(_ raw: String) -> String? {
        guard let data = raw.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data),
              let prettyData = try? JSONSerialization.data(
                  withJSONObject: object,
                  options: [.prettyPrinted, .sortedKeys]
              ),
              let pretty = String(data: prettyData, encoding: .utf8)
        else {
            return nil
        }
        return pretty
    }
}
