//
// WebSearchToolRenderer.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import SwiftUI

// MARK: - WebSearchToolRenderer

/// Renderer for WebSearch tool calls
public struct WebSearchToolRenderer: View {
    // MARK: Lifecycle

    public init(query: String) {
        self.query = query
    }

    // MARK: Public

    public var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "globe")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("Searching web for ")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                +
                Text(self.query)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
        }
    }

    // MARK: Private

    private let query: String
}
