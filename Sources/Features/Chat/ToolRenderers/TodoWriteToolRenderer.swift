//
// TodoWriteToolRenderer.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import SwiftUI
import TENEXCore

// MARK: - TodoWriteToolRenderer

/// Renderer for TodoWrite tool calls with status icons
public struct TodoWriteToolRenderer: View {
    // MARK: Lifecycle

    public init(todos: [TodoItem]) {
        self.todos = todos
    }

    // MARK: Public

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "checklist")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)

                Text("Updating task list")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }

            // Todo items
            if !todos.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(todos.enumerated()), id: \.offset) { _, todo in
                        todoRow(todo)
                    }
                }
                .padding(.leading, 24)
            }
        }
    }

    // MARK: Private

    private let todos: [TodoItem]

    @ViewBuilder
    private func todoRow(_ todo: TodoItem) -> some View {
        HStack(spacing: 8) {
            statusIcon(for: todo.status)
            Text(todo.content)
                .font(.system(size: 14))
                .foregroundStyle(textColor(for: todo.status))
                .strikethrough(todo.status == .completed, color: .secondary)
        }
    }

    @ViewBuilder
    private func statusIcon(for status: TodoItem.Status) -> some View {
        switch status {
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 14))
                .foregroundStyle(.green)

        case .inProgress:
            Image(systemName: "arrow.circlepath")
                .font(.system(size: 14))
                .foregroundStyle(.blue)
                .symbolEffect(.rotate, options: .repeating)

        case .pending:
            Image(systemName: "circle")
                .font(.system(size: 14))
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
