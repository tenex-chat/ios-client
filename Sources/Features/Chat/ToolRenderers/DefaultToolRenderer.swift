//
// DefaultToolRenderer.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import SwiftUI

// MARK: - DefaultToolRenderer

/// Fallback renderer for unknown tool types
public struct DefaultToolRenderer: View {
    // MARK: Lifecycle

    public init(toolName: String) {
        self.toolName = toolName
    }

    // MARK: Public

    public var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "gearshape")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("Executing ")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                +
                Text(self.toolName)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: Private

    private let toolName: String
}
