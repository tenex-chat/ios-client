//
// BashToolRenderer.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import SwiftUI

// MARK: - BashToolRenderer

/// Renderer for Bash tool calls
public struct BashToolRenderer: View {
    // MARK: Lifecycle

    public init(command: String, description: String?) {
        self.command = command
        self.description = description
    }

    // MARK: Public

    public var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "terminal")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text(self.displayText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    // MARK: Private

    private let command: String
    private let description: String?

    private var displayText: String {
        // Prefer description if available
        if let description, !description.isEmpty {
            return description
        }

        // Truncate long commands
        let maxLength = 60
        if self.command.count <= maxLength {
            return self.command
        }
        return String(self.command.prefix(maxLength)) + "..."
    }
}
