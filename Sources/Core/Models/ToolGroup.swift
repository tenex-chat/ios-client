//
// ToolGroup.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation

/// Represents a group of related tools
public struct ToolGroup: Identifiable, Sendable {
    // MARK: Lifecycle

    /// Initialize a tool group
    /// - Parameters:
    ///   - id: Unique identifier
    ///   - name: Display name
    ///   - tools: List of tools in the group
    public init(id: String, name: String, tools: [String]) {
        self.id = id
        self.name = name
        self.tools = tools
    }

    // MARK: Public

    /// Unique identifier for the group
    public let id: String

    /// Display name for the group (e.g., "MCP: xcode", "GIT", "individual-tool-name")
    public let name: String

    /// Tools in this group
    public let tools: [String]

    /// Whether this group contains only a single tool
    public var isSingleTool: Bool {
        self.tools.count == 1
    }
}
