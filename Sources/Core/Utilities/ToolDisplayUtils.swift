//
// ToolDisplayUtils.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation

// MARK: - ToolCategory

/// Tool categories for grouping and display purposes
public enum ToolCategory: String, Sendable {
    case read
    case write
    case execute
    case delegate
    case search
    case other
}

// MARK: - VerbConfig

/// Verb configuration for each category
public struct VerbConfig: Sendable {
    /// Active tense verb (e.g., "Reading", "Writing")
    public let activeVerb: String

    /// Past tense verb (e.g., "Read", "Wrote")
    public let pastVerb: String

    /// Singular noun (e.g., "file", "command")
    public let noun: String

    /// Plural noun (e.g., "files", "commands")
    public let pluralNoun: String
}

// MARK: - ToolActionInfo

/// Information extracted from a tool call for display purposes
public struct ToolActionInfo: Sendable {
    public let category: ToolCategory
    public let toolName: String
    public let detail: String?
}

// MARK: - ToolDisplayUtils

/// Utilities for generating display text for tool calls
public enum ToolDisplayUtils {
    // MARK: Public

    // MARK: - Category Mapping

    /// Get the category for a tool name
    public static func getCategory(for toolName: String?) -> ToolCategory {
        guard let toolName else {
            return .other
        }

        switch toolName {
        // Read operations
        case "Read", "read_path", "read_file", "ReadFile", "cat":
            return .read

        // Write operations
        case "Write", "write_file", "WriteFile", "Edit", "EditFile", "edit_file",
             "NotebookEdit", "create_file", "CreateFile":
            return .write

        // Search operations
        case "Glob", "Grep", "codebase_search", "search_files", "find_files", "Search":
            return .search

        // Execute operations
        case "Bash", "shell", "run_command", "execute_command", "Terminal":
            return .execute

        // Delegate operations
        case "delegate", "delegate_external", "Task", "spawn_agent":
            return .delegate

        default:
            return .other
        }
    }

    /// Get verb configuration for a category
    public static func getVerbs(for category: ToolCategory) -> VerbConfig {
        switch category {
        case .read:
            VerbConfig(activeVerb: "Reading", pastVerb: "Read", noun: "file", pluralNoun: "files")
        case .write:
            VerbConfig(activeVerb: "Writing", pastVerb: "Wrote", noun: "file", pluralNoun: "files")
        case .execute:
            VerbConfig(activeVerb: "Executing", pastVerb: "Executed", noun: "command", pluralNoun: "commands")
        case .delegate:
            VerbConfig(activeVerb: "Delegating to", pastVerb: "Delegated to", noun: "agent", pluralNoun: "agents")
        case .search:
            VerbConfig(activeVerb: "Searching for", pastVerb: "Searched for", noun: "query", pluralNoun: "queries")
        case .other:
            VerbConfig(activeVerb: "Using", pastVerb: "Used", noun: "tool", pluralNoun: "tools")
        }
    }

    // MARK: - Action Info Extraction

    /// Get action info for a tool call
    public static func getActionInfo(for toolCall: ToolCall) -> ToolActionInfo {
        let category = getCategory(for: toolCall.name)
        let detail = extractDetail(from: toolCall, category: category)
        return ToolActionInfo(category: category, toolName: toolCall.name, detail: detail)
    }

    // MARK: - Display Text Generation

    /// Generate display text for a group of tool calls
    /// - Parameters:
    ///   - toolCalls: The tool calls to display
    ///   - isActive: Whether the tools are currently running
    /// - Returns: Human-readable display text
    public static func getGroupDisplayText(toolCalls: [ToolCall], isActive: Bool) -> String {
        guard !toolCalls.isEmpty else {
            return ""
        }

        let actions = toolCalls.map { getActionInfo(for: $0) }
        let dominantCategory = getDominantCategory(actions)
        let verbs = getVerbs(for: dominantCategory)

        if isActive {
            if toolCalls.count == 1, let action = actions.first {
                let actionVerbs = getVerbs(for: action.category)
                if let detail = action.detail {
                    return "\(actionVerbs.activeVerb) \(detail)"
                }
                return "\(actionVerbs.activeVerb) 1 \(actionVerbs.noun)"
            } else {
                return "\(verbs.activeVerb) \(toolCalls.count) \(verbs.pluralNoun)"
            }
        } else {
            if toolCalls.count == 1, let action = actions.first {
                let actionVerbs = getVerbs(for: action.category)
                if let detail = action.detail {
                    return "\(actionVerbs.pastVerb) \(detail)"
                }
                return "\(actionVerbs.pastVerb) 1 \(actionVerbs.noun)"
            } else {
                return "\(verbs.pastVerb) \(toolCalls.count) \(verbs.pluralNoun)"
            }
        }
    }

    /// Generate display text for an individual tool call
    public static func getIndividualDisplayText(for toolCall: ToolCall) -> String {
        let action = getActionInfo(for: toolCall)
        let verbs = getVerbs(for: action.category)

        if let detail = action.detail {
            return "\(verbs.pastVerb) \(detail)"
        }
        return "\(verbs.pastVerb) \(action.toolName)"
    }

    // MARK: - Icon Names

    /// Get SF Symbol name for a tool category
    public static func getIconName(for category: ToolCategory) -> String {
        switch category {
        case .read:
            "doc.text"
        case .write:
            "pencil"
        case .execute:
            "terminal"
        case .delegate:
            "person.2"
        case .search:
            "magnifyingglass"
        case .other:
            "gearshape"
        }
    }

    /// Get the dominant icon name for a group of tool calls
    public static func getGroupIconName(toolCalls: [ToolCall]) -> String {
        guard !toolCalls.isEmpty else {
            return "gearshape"
        }

        let actions = toolCalls.map { getActionInfo(for: $0) }
        let dominantCategory = getDominantCategory(actions)
        return getIconName(for: dominantCategory)
    }

    // MARK: Private

    // MARK: - Private Helpers

    /// Extract relevant detail from a tool call based on its category
    private static func extractDetail(from toolCall: ToolCall, category: ToolCategory) -> String? {
        switch category {
        case .read, .write:
            // Try various path argument names
            let path = toolCall.string(for: "file_path") ?? toolCall.string(for: "path") ??
                toolCall.string(for: "filepath") ?? toolCall.string(for: "filename") ??
                toolCall.string(for: "file") ?? toolCall.string(for: "target") ??
                toolCall.string(for: "notebook_path")
            if let path {
                return ToolCall.getDisplayPath(
                    fullPath: path,
                    projectDTag: toolCall.projectDTag,
                    branch: toolCall.branch
                )
            }
            return nil

        case .execute:
            if let command = toolCall.string(for: "command") {
                return command.count > 50 ? String(command.prefix(47)) + "..." : command
            }
            return nil

        case .delegate:
            // Check delegations array first, then other argument names
            let delegations = toolCall.delegations()
            if let firstRecipient = delegations.first?.recipient, !firstRecipient.isEmpty {
                return truncate(firstRecipient, maxLength: 30)
            }
            let agentName = toolCall.string(for: "agent") ?? toolCall.string(for: "subagent_type") ??
                toolCall.string(for: "recipient") ?? toolCall.string(for: "description")
            if let agentName {
                return truncate(agentName, maxLength: 30)
            }
            return nil

        case .search:
            if let query = toolCall.string(for: "query") ?? toolCall.string(for: "pattern") {
                let truncated = truncate(query, maxLength: 30)
                let searchType = toolCall.string(for: "searchType")
                if searchType == "filename" {
                    return "files matching \"\(truncated)\""
                }
                return "\"\(truncated)\""
            }
            return nil

        case .other:
            return nil
        }
    }

    /// Determine the dominant category for a set of actions
    private static func getDominantCategory(_ actions: [ToolActionInfo]) -> ToolCategory {
        guard !actions.isEmpty else {
            return .other
        }

        let firstCategory = actions[0].category
        let allSame = actions.allSatisfy { $0.category == firstCategory }

        return allSame ? firstCategory : .other
    }

    /// Truncate a string to a maximum length
    private static func truncate(_ string: String, maxLength: Int) -> String {
        if string.count > maxLength {
            return String(string.prefix(maxLength - 3)) + "..."
        }
        return string
    }
}
