//
// MCPToolSettingsRow.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import SwiftUI

// MARK: - MCPToolSettingsRow

/// Display MCP tool with remove button
struct MCPToolSettingsRow: View {
    // MARK: Lifecycle

    init(toolID: String, onRemove: @escaping () -> Void) {
        self.toolID = toolID
        self.onRemove = onRemove
    }

    // MARK: Internal

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("MCP Tool")
                    .font(.body)

                Text(toolID.prefix(16) + "...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospaced()
            }

            Spacer()

            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.red)
            }
            .buttonStyle(.borderless)
        }
    }

    // MARK: Private

    private let toolID: String
    private let onRemove: () -> Void
}
