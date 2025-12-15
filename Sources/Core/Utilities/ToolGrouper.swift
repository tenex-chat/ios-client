//
// ToolGrouper.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation

/// Utility for intelligently grouping tools by MCP server, common prefixes, or as individuals
public enum ToolGrouper {
    // MARK: Public

    // MARK: - Public Methods

    /// Group tools intelligently by MCP server, common prefixes, or as individuals
    /// - Parameter tools: Array of tool names to group
    /// - Returns: Array of ToolGroup objects, sorted alphabetically
    public static func groupTools(_ tools: [String]) -> [ToolGroup] {
        var groups: [String: [String]] = [:]
        var ungrouped: [String] = []

        for tool in tools {
            // MCP tools: mcp__<server>__<method>
            if tool.hasPrefix(Patterns.mcpPrefix) {
                if let mcpGroup = extractMCPGroup(from: tool) {
                    groups[mcpGroup, default: []].append(tool)
                    continue
                }
            }

            // Common prefixes: git_status, git_commit → "GIT"
            if let prefixGroup = extractPrefixGroup(from: tool, in: tools) {
                if !groups[prefixGroup, default: []].contains(tool) {
                    groups[prefixGroup, default: []].append(tool)
                }
                continue
            }

            // No group found - add to ungrouped
            ungrouped.append(tool)
        }

        return self.buildGroupArray(from: groups, ungrouped: ungrouped)
    }

    // MARK: Private

    // MARK: - Constants

    /// Pattern constants for tool grouping
    private enum Patterns {
        /// Prefix for MCP tools (mcp__<server>__<method>)
        static let mcpPrefix = "mcp__"

        /// Regex pattern for common prefixes (e.g., "git_", "npm_")
        static let commonPrefix = "^([a-z_]+?)_"

        /// Minimum number of tools required to form a group
        static let minimumGroupSize = 2
    }

    // MARK: - Private Methods

    /// Extract MCP group name from MCP tool name
    /// - Parameter tool: Tool name (e.g., "mcp__xcode__build_sim")
    /// - Returns: Group name (e.g., "MCP: xcode") or nil
    private static func extractMCPGroup(from tool: String) -> String? {
        let parts = tool.split(separator: "_")
        guard parts.count >= 3 else {
            return nil
        }

        let serverName = String(parts[1])
        return "MCP: \(serverName)"
    }

    /// Extract prefix group name from tool name if enough similar tools exist
    /// - Parameters:
    ///   - tool: Tool name (e.g., "git_status")
    ///   - tools: All available tools
    /// - Returns: Group name (e.g., "GIT") or nil
    private static func extractPrefixGroup(from tool: String, in tools: [String]) -> String? {
        guard let prefixMatch = tool.range(of: Patterns.commonPrefix, options: .regularExpression) else {
            return nil
        }

        let prefix = String(tool[prefixMatch]).dropLast() // Remove trailing "_"
        let similarTools = tools.filter { $0.hasPrefix(prefix + "_") }

        guard similarTools.count >= Patterns.minimumGroupSize else {
            return nil
        }

        return prefix.uppercased()
    }

    /// Build final array of ToolGroups from grouped and ungrouped tools
    /// - Parameters:
    ///   - groups: Dictionary of group names to tools
    ///   - ungrouped: Array of ungrouped tool names
    /// - Returns: Sorted array of ToolGroup objects
    private static func buildGroupArray(
        from groups: [String: [String]],
        ungrouped: [String]
    ) -> [ToolGroup] {
        var result: [ToolGroup] = []

        // Add grouped tools
        for (name, tools) in groups.sorted(by: { $0.key < $1.key }) {
            result.append(ToolGroup(
                id: name,
                name: name,
                tools: tools.sorted()
            ))
        }

        // Add ungrouped tools as individual groups
        for tool in ungrouped.sorted() {
            result.append(ToolGroup(
                id: tool,
                name: tool,
                tools: [tool]
            ))
        }

        return result
    }
}
