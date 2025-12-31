//
// DelegationPreview.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import NDKSwiftCore
import NDKSwiftUI
import Observation
import SwiftUI
import TENEXCore

// MARK: - DelegationStatus

enum DelegationStatus {
    case working
    case done
}

// MARK: - DelegationPreviewViewModel

@MainActor
@Observable
final class DelegationPreviewViewModel {
    // MARK: Lifecycle

    init(ndk: NDK, conversationID: String) {
        self.ndk = ndk
        self.conversationID = conversationID
    }

    // MARK: Internal

    private(set) var events: [NDKEvent] = []

    var rootEvent: NDKEvent? {
        events.first { $0.id == conversationID }
    }

    var agentPubkey: String? {
        rootEvent?.tagValue("p")
    }

    var projectReference: String? {
        rootEvent?.tagValue("a")
    }

    var todoItems: [TodoItem] {
        let sortedEvents = events.sorted { ($0.createdAt) < ($1.createdAt) }
        return aggregateTodoState(from: sortedEvents)
    }

    var progress: (completed: Int, total: Int)? {
        let todos = todoItems
        guard !todos.isEmpty else {
            return nil
        }
        let completed = todos.filter { $0.status == .completed }.count
        return (completed, todos.count)
    }

    var recentMessage: NDKEvent? {
        events
            .filter { event in
                event.kind == 1 &&
                    event.tagValue("tool") == nil &&
                    !event.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
            .max { $0.createdAt < $1.createdAt }
    }

    var status: DelegationStatus {
        guard let rootEvent,
              let mostRecentKind1 = events.filter({ $0.kind == 1 }).max(by: { $0.createdAt < $1.createdAt })
        else {
            return .working
        }

        let delegatorPubkey = rootEvent.pubkey
        guard let delegatedToPubkey = rootEvent.tagValue("p") else {
            return .working
        }

        let lastEventFromDelegate = mostRecentKind1.pubkey == delegatedToPubkey
        let lastEventTagsDelegator = mostRecentKind1.tags(withName: "p")
            .contains { $0.count > 1 && $0[1] == delegatorPubkey }

        if lastEventFromDelegate, lastEventTagsDelegator {
            return .done
        }

        return .working
    }

    func subscribe() async {
        // Subscribe to root event by ID
        let rootFilter = NDKFilter(ids: [conversationID])
        let rootSubscription = ndk.subscribe(filter: rootFilter)

        // Subscribe to replies by #e tag
        let repliesFilter = NDKFilter(tags: ["e": Set([conversationID])])
        let repliesSubscription = ndk.subscribe(filter: repliesFilter)

        // Process both subscriptions concurrently
        await withTaskGroup(of: Void.self) { group in
            group.addTask { @MainActor in
                for await batch in rootSubscription.events {
                    self.events.append(contentsOf: batch)
                }
            }

            group.addTask { @MainActor in
                for await batch in repliesSubscription.events {
                    self.events.append(contentsOf: batch)
                }
            }
        }
    }

    // MARK: Private

    private let ndk: NDK
    private let conversationID: String

    private func aggregateTodoState(from events: [NDKEvent]) -> [TodoItem] {
        var todosByContent: [String: TodoItem] = [:]

        for event in events {
            guard event.tagValue("tool") == "TodoWrite",
                  let toolArgsTag = event.tags(withName: "tool-args").first,
                  toolArgsTag.count > 1,
                  let jsonData = toolArgsTag[1].data(using: .utf8),
                  let dict = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                  let todosArray = dict["todos"] as? [[String: Any]]
            else {
                continue
            }

            for todoDict in todosArray {
                guard let content = todoDict["content"] as? String,
                      let statusString = todoDict["status"] as? String,
                      let status = TodoItem.Status(rawValue: statusString)
                else {
                    continue
                }
                let activeForm = todoDict["activeForm"] as? String ?? content
                let item = TodoItem(content: content, status: status, activeForm: activeForm)
                todosByContent[item.content] = item
            }
        }

        return Array(todosByContent.values)
    }
}

// MARK: - DelegationPreview

struct DelegationPreview: View {
    // MARK: Lifecycle

    init(
        ndk: NDK,
        conversationID: String,
        recipientName: String?,
        prompt: String?
    ) {
        self.ndk = ndk
        self.conversationID = conversationID
        self.recipientName = recipientName
        self.prompt = prompt
        self._viewModel = State(initialValue: DelegationPreviewViewModel(ndk: ndk, conversationID: conversationID))
    }

    // MARK: Internal

    var body: some View {
        NavigationLink(value: navigationRoute) {
            cardContent
        }
        .buttonStyle(.plain)
        .disabled(viewModel.projectReference == nil)
        .task {
            await viewModel.subscribe()
        }
    }

    private var navigationRoute: AppRoute {
        .thread(
            projectID: viewModel.projectReference ?? "",
            threadID: conversationID
        )
    }

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            if viewModel.events.isEmpty {
                emptyState
            } else {
                if !viewModel.todoItems.isEmpty {
                    todoSection
                }

                if let recentMessage = viewModel.recentMessage {
                    latestActivitySection(recentMessage)
                }
            }
        }
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(.separator), lineWidth: 0.5)
        )
        .frame(maxWidth: 320)
    }

    // MARK: Private

    private let ndk: NDK
    private let conversationID: String
    private let recipientName: String?
    private let prompt: String?

    @State private var viewModel: DelegationPreviewViewModel

    private var header: some View {
        HStack(spacing: 10) {
            if let agentPubkey = viewModel.agentPubkey {
                NDKUIProfilePicture(ndk: ndk, pubkey: agentPubkey, size: 26)
            } else {
                Circle()
                    .fill(Color.accentColor.opacity(0.3))
                    .frame(width: 26, height: 26)
                    .overlay(
                        Text("?")
                            .font(.caption)
                            .fontWeight(.semibold)
                    )
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(recipientName ?? "Agent")
                    .font(.caption)
                    .fontWeight(.semibold)

                if let prompt, !prompt.isEmpty {
                    Text(prompt)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            statusBadge
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(.tertiarySystemBackground))
    }

    private var statusBadge: some View {
        Text(viewModel.status == .done ? "done" : "working")
            .font(.system(size: 9))
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(
                viewModel.status == .done
                    ? Color.green.opacity(0.2)
                    : Color.yellow.opacity(0.2)
            )
            .foregroundStyle(
                viewModel.status == .done
                    ? Color.green
                    : Color.yellow
            )
            .clipShape(Capsule())
    }

    private var todoSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let progress = viewModel.progress {
                Text("Progress (\(progress.completed)/\(progress.total))")
                    .font(.system(size: 9))
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary)
                    .tracking(0.5)
            } else {
                Text("Tasks")
                    .font(.system(size: 9))
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary)
                    .tracking(0.5)
            }

            VStack(alignment: .leading, spacing: 3) {
                ForEach(viewModel.todoItems, id: \.content) { item in
                    todoRow(item)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    private func todoRow(_ item: TodoItem) -> some View {
        HStack(alignment: .top, spacing: 6) {
            todoCheckbox(item.status)
            Text(item.content)
                .font(.system(size: 11))
                .foregroundStyle(item.status == .completed ? .secondary : .primary)
                .strikethrough(item.status == .completed)
        }
    }

    @ViewBuilder
    private func todoCheckbox(_ status: TodoItem.Status) -> some View {
        switch status {
        case .completed:
            Image(systemName: "checkmark")
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 14, height: 14)
                .background(Color.green)
                .clipShape(RoundedRectangle(cornerRadius: 3))

        case .inProgress:
            ProgressView()
                .scaleEffect(0.5)
                .frame(width: 14, height: 14)

        case .pending:
            RoundedRectangle(cornerRadius: 3)
                .stroke(Color(.separator), lineWidth: 1.5)
                .frame(width: 14, height: 14)
        }
    }

    private func latestActivitySection(_ event: NDKEvent) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Latest Activity")
                .font(.system(size: 9))
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
                .tracking(0.5)

            Text(event.content)
                .font(.system(size: 11))
                .lineLimit(3)

            Text(formatRelativeTime(event.createdAt))
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var emptyState: some View {
        HStack(spacing: 8) {
            ProgressView()
                .scaleEffect(0.7)

            Text("Waiting for activity...")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 16)
    }

    private func formatRelativeTime(_ timestamp: Int64) -> String {
        let now = Int64(Date().timeIntervalSince1970)
        let diff = now - timestamp
        let oneHour: Int64 = 3600
        let oneDay: Int64 = 86_400

        if diff < 60 {
            return "just now"
        }
        if diff < oneHour {
            return "\(diff / 60) min ago"
        }
        if diff < oneDay {
            return "\(diff / oneHour)h ago"
        }
        return "\(diff / oneDay)d ago"
    }
}
