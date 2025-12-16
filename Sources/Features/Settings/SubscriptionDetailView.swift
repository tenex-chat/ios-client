//
// SubscriptionDetailView.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import NDKSwiftCore
import SwiftUI
import TENEXShared

// MARK: - SubscriptionDetailView

struct SubscriptionDetailView: View {
    // MARK: Internal

    let relay: NDKRelay
    let subscription: NDKRelaySubscriptionInfo

    var body: some View {
        List {
            subscriptionInfoSection
            filtersSection
            if isLoading {
                loadingSection
            } else if let error {
                errorSection(error)
            } else {
                eventsSection
            }
        }
        .navigationTitle("Subscription Details")
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { Task { await fetchEvents() } } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(isLoading)
                }
            }
            .task { await fetchEvents() }
    }

    // MARK: Private

    @Environment(\.dismiss) private var dismiss
    @Environment(\.ndk) private var ndk
    @State private var events: [NDKEvent] = []
    @State private var isLoading = false
    @State private var error: String?

    private var subscriptionInfoSection: some View {
        Section("Subscription Info") {
            LabeledContent("ID") {
                Text(subscription.id)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
            }

            LabeledContent("Event Count") {
                Text("\(subscription.eventCount)")
                    .font(.system(.body, design: .monospaced))
            }

            LabeledContent("Filters") {
                Text("\(subscription.filters.count)")
                    .font(.system(.body, design: .monospaced))
            }

            if let lastEvent = subscription.lastEventAt {
                LabeledContent("Last Event") {
                    Text(FormattingUtilities.relative(lastEvent))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            LabeledContent("Created") {
                Text(FormattingUtilities.relative(subscription.createdAt))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var filtersSection: some View {
        Section("Filters (\(subscription.filters.count))") {
            ForEach(Array(subscription.filters.enumerated()), id: \.offset) { index, filter in
                FilterView(filter: filter, index: index)
            }
        }
    }

    private var loadingSection: some View {
        Section {
            HStack {
                ProgressView()
                Text("Loading events...")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var eventsSection: some View {
        Section("Events (\(events.count))") {
            if events.isEmpty {
                Text("No events found")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 24)
            } else {
                ForEach(events, id: \.id) { event in
                    EventRow(event: event)
                }
            }
        }
    }

    private func errorSection(_ errorMessage: String) -> some View {
        Section {
            HStack {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(.red)
                Text(errorMessage)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func fetchEvents() async {
        guard let ndk else {
            error = "NDK not available"
            return
        }

        isLoading = true
        error = nil

        var fetchedEvents: [NDKEvent] = []

        await withTaskGroup(of: [NDKEvent].self) { group in
            for filter in subscription.filters {
                group.addTask {
                    var events: [NDKEvent] = []
                    let subscription = ndk.subscribe(filter: filter)
                    for await batch in subscription.events {
                        events.append(contentsOf: batch)
                    }
                    return events
                }
            }

            for await filterEvents in group {
                fetchedEvents.append(contentsOf: filterEvents)
            }
        }

        await MainActor.run {
            events = fetchedEvents.sorted { $0.createdAt > $1.createdAt }
            isLoading = false
        }
    }
}

// MARK: - FilterView

private struct FilterView: View {
    // MARK: Internal

    let filter: NDKFilter
    let index: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Filter #\(index + 1)")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 4) {
                kindsRow
                authorsRow
                idsRow
                limitRow
                sinceRow
                untilRow
                tagsRows
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: Private

    @ViewBuilder private var kindsRow: some View {
        if let kinds = filter.kinds, !kinds.isEmpty {
            filterDetail(label: "Kinds", value: kinds.map { "\($0)" }.joined(separator: ", "))
        }
    }

    @ViewBuilder private var authorsRow: some View {
        if let authors = filter.authors, !authors.isEmpty {
            filterDetail(label: "Authors", value: "\(authors.count) pubkeys")
        }
    }

    @ViewBuilder private var idsRow: some View {
        if let ids = filter.ids, !ids.isEmpty {
            filterDetail(label: "IDs", value: "\(ids.count) event IDs")
        }
    }

    @ViewBuilder private var limitRow: some View {
        if let limit = filter.limit {
            filterDetail(label: "Limit", value: "\(limit)")
        }
    }

    @ViewBuilder private var sinceRow: some View {
        if let since = filter.since {
            filterDetail(
                label: "Since",
                value: FormattingUtilities.shortDateTime(Date(timeIntervalSince1970: TimeInterval(since)))
            )
        }
    }

    @ViewBuilder private var untilRow: some View {
        if let until = filter.until {
            filterDetail(
                label: "Until",
                value: FormattingUtilities.shortDateTime(Date(timeIntervalSince1970: TimeInterval(until)))
            )
        }
    }

    @ViewBuilder private var tagsRows: some View {
        if let tags = filter.tags, !tags.isEmpty {
            ForEach(Array(tags.keys.sorted()), id: \.self) { tagName in
                if let values = tags[tagName] {
                    filterDetail(label: "#\(tagName)", value: values.joined(separator: ", "))
                }
            }
        }
    }

    private func filterDetail(label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 4) {
            Text("\(label):")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(width: 60, alignment: .leading)

            Text(value)
                .font(.system(.caption2, design: .monospaced))
                .lineLimit(3)
                .textSelection(.enabled)
        }
    }
}

// MARK: - EventRow

private struct EventRow: View {
    let event: NDKEvent

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Kind \(event.kind)")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.blue)

                Spacer()

                Text(FormattingUtilities.relative(Date(timeIntervalSince1970: TimeInterval(event.createdAt))))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Text(event.id)
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Text(event.pubkey.prefix(16) + "...")
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.secondary)

            if !event.content.isEmpty {
                Text(event.content)
                    .font(.caption2)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }
}
