//
// AgentTodoListView.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import SwiftUI
import TENEXCore

// MARK: - AgentTodoListView

/// Displays aggregated todos for an agent message group
/// Shows completion progress and individual todo items with status icons
struct AgentTodoListView: View {
    // MARK: Lifecycle

    init(todos: [TodoItem]) {
        self.todos = todos
    }

    // MARK: Internal

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Progress header
            HStack(spacing: 6) {
                Image(systemName: "checklist")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("\(completedCount)/\(todos.count) done")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Todo items
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(todos.enumerated()), id: \.offset) { _, todo in
                    todoRow(todo)
                }
            }
        }
        .padding(.leading, 44) // Align with message content (past avatar)
        .padding(.vertical, 6)
    }

    // MARK: Private

    private let todos: [TodoItem]

    private var completedCount: Int {
        todos.filter { $0.status == .completed }.count
    }

    @ViewBuilder
    private func todoRow(_ todo: TodoItem) -> some View {
        HStack(spacing: 6) {
            statusIcon(for: todo.status)
            Text(todo.content)
                .font(.caption)
                .foregroundStyle(textColor(for: todo.status))
                .strikethrough(todo.status == .completed, color: .secondary)
        }
    }

    @ViewBuilder
    private func statusIcon(for status: TodoItem.Status) -> some View {
        switch status {
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.green)

        case .inProgress:
            if #available(iOS 18.0, macOS 15.0, *) {
                Image(systemName: "arrow.circlepath")
                    .font(.caption)
                    .foregroundStyle(.blue)
                    .symbolEffect(.rotate, options: .repeating)
            } else {
                Image(systemName: "arrow.circlepath")
                    .font(.caption)
                    .foregroundStyle(.blue)
            }

        case .pending:
            Image(systemName: "circle")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func textColor(for status: TodoItem.Status) -> Color {
        switch status {
        case .completed:
            .secondary
        case .inProgress:
            .primary
        case .pending:
            .secondary
        }
    }
}
