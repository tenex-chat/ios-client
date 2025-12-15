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
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text("Updating task list")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Todo items
            if !self.todos.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(self.todos.enumerated()), id: \.offset) { _, todo in
                        self.todoRow(todo)
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
            self.statusIcon(for: todo.status)
            Text(todo.content)
                .font(.subheadline)
                .foregroundStyle(self.textColor(for: todo.status))
                .strikethrough(todo.status == .completed, color: .secondary)
        }
    }

    @ViewBuilder
    private func statusIcon(for status: TodoItem.Status) -> some View {
        switch status {
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .font(.subheadline)
                .foregroundStyle(.green)

        case .inProgress:
            if #available(iOS 18.0, macOS 15.0, *) {
                Image(systemName: "arrow.circlepath")
                    .font(.subheadline)
                    .foregroundStyle(.blue)
                    .symbolEffect(.rotate, options: .repeating)
            } else {
                Image(systemName: "arrow.circlepath")
                    .font(.subheadline)
                    .foregroundStyle(.blue)
            }

        case .pending:
            Image(systemName: "circle")
                .font(.subheadline)
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
