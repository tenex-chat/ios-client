//
// ShellToolRenderer.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import SwiftUI

// MARK: - ShellToolRenderer

/// Renderer for shell tool calls
public struct ShellToolRenderer: View {
    // MARK: Lifecycle

    public init(command: String) {
        self.command = command
    }

    // MARK: Public

    public var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "terminal")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("Executing: ")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                +
                Text(self.displayText)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
        }
        .lineLimit(1)
    }

    // MARK: Private

    private let command: String

    private var displayText: String {
        // Truncate long commands
        let maxLength = 80
        if self.command.count <= maxLength {
            return self.command
        }
        return String(self.command.prefix(maxLength)) + "..."
    }
}
