//
// ToolCallView.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import NDKSwiftCore
import SwiftUI
import TENEXCore

// MARK: - ToolCallView

/// Dispatcher view that routes tool calls to specialized renderers
public struct ToolCallView: View {
    // MARK: Lifecycle

    public init(toolCall: ToolCall) {
        self.toolCall = toolCall
    }

    // MARK: Public

    public var body: some View {
        rendererForTool
    }

    // MARK: Private

    @Environment(\.ndk) private var ndk

    private let toolCall: ToolCall

    @ViewBuilder private var rendererForTool: some View {
        switch toolCall.name {
        case "Read",
             "Edit":
            ReadToolRenderer(displayPath: toolCall.displayPath(for: "file_path"))
        case "read_path":
            ReadToolRenderer(displayPath: toolCall.string(for: "path") ?? "")
        case "Write":
            WriteToolRenderer(
                displayPath: toolCall.displayPath(for: "file_path"),
                content: toolCall.string(for: "content") ?? ""
            )
        case "Glob":
            SearchToolRenderer(pattern: toolCall.string(for: "pattern", default: "**/*"))
        case "Grep":
            SearchToolRenderer(pattern: toolCall.string(for: "pattern", default: ""))
        case "Bash":
            BashToolRenderer(
                command: toolCall.string(for: "command") ?? "",
                description: toolCall.string(for: "description")
            )
        case "shell":
            ShellToolRenderer(command: toolCall.string(for: "command") ?? "")
        case "TodoWrite":
            TodoWriteToolRenderer(todos: toolCall.todos())
        case "codebase_search":
            CodebaseSearchToolRenderer(
                query: toolCall.string(for: "query") ?? "",
                searchType: toolCall.string(for: "searchType", default: "both"),
                fileType: toolCall.string(for: "fileType")
            )
        case "delegate":
            DelegateToolRenderer(
                ndk: ndk,
                delegations: toolCall.delegations(),
                conversationIDs: toolCall.conversationIDs
            )
        case "Task":
            TaskToolRenderer(
                description: toolCall.string(for: "description"),
                subagentType: toolCall.string(for: "subagent_type")
            )
        case "WebSearch":
            WebSearchToolRenderer(query: toolCall.string(for: "query") ?? "")
        case "WebFetch":
            WebFetchToolRenderer(url: toolCall.string(for: "url") ?? "")
        default:
            DefaultToolRenderer(toolName: toolCall.name)
        }
    }
}
