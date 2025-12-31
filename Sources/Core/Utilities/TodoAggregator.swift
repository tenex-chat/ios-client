//
// TodoAggregator.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation

// MARK: - TodoAggregator

/// Aggregates todo state from a sequence of messages
/// TodoWrite tool calls replace the entire list each time
public enum TodoAggregator {
    /// Aggregate todos from messages in a group
    /// Returns the final todo state after processing all TodoWrite calls
    /// - Parameter messages: Messages to scan for TodoWrite tool calls
    /// - Returns: The aggregated todo list (from the last TodoWrite call)
    public static func aggregate(from messages: [Message]) -> [TodoItem] {
        var todos: [TodoItem] = []

        for message in messages {
            guard let toolCall = message.toolCall,
                  toolCall.name == "TodoWrite"
            else {
                continue
            }

            // TodoWrite replaces the entire list
            todos = toolCall.todos()
        }

        return todos
    }
}
