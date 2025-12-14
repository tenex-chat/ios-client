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
                .font(.system(size: 14))
                .foregroundStyle(.secondary)

            Text("Executing ")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                +
                Text(toolName)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: Private

    private let toolName: String
}
