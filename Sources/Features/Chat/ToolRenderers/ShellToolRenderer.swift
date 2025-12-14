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
                .font(.system(size: 14))
                .foregroundStyle(.secondary)

            Text("Executing: ")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                +
                Text(displayText)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .lineLimit(1)
    }

    // MARK: Private

    private let command: String

    private var displayText: String {
        // Truncate long commands
        let maxLength = 80
        if command.count <= maxLength {
            return command
        }
        return String(command.prefix(maxLength)) + "..."
    }
}
