//
// MCPTool.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation
import NDKSwiftCore

/// Represents an MCP Tool (Nostr kind:4200)
public struct MCPTool: Identifiable, Sendable, Equatable {
    // MARK: Public

    /// The event ID
    public let id: String

    /// The pubkey of the tool author
    public let pubkey: String

    /// The tool name
    public let name: String

    /// The tool description
    public let description: String

    /// The tool command
    public let command: String

    /// The tool parameters (JSON)
    public let parameters: [String: Any]?

    /// When the tool was created
    public let createdAt: Date

    /// Create an MCPTool from a Nostr event
    /// - Parameter event: The NDKEvent (must be kind:4200)
    /// - Returns: An MCPTool instance, or nil if the event is invalid
    public static func from(event: NDKEvent) -> Self? {
        guard event.kind == 4200 else { return nil }

        let name = event.tags(withName: "name").first?.count ?? 0 > 1 ? event.tags(withName: "name").first?[1] : ""
        let command = event.tags(withName: "command").first?.count ?? 0 > 1 ? event.tags(withName: "command").first?[1] : ""

        let paramsString = event.tags(withName: "params").first?.count ?? 0 > 1 ? event.tags(withName: "params").first?[1] : nil
        var parameters: [String: Any]? = nil
        if let data = paramsString?.data(using: .utf8) {
            parameters = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        }

        return Self(
            id: event.id,
            pubkey: event.pubkey,
            name: name ?? "",
            description: event.content,
            command: command ?? "",
            parameters: parameters,
            createdAt: Date(timeIntervalSince1970: TimeInterval(event.createdAt))
        )
    }

    public static func == (lhs: MCPTool, rhs: MCPTool) -> Bool {
        lhs.id == rhs.id
    }
}
