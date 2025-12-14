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
                .font(.system(size: 14))
                .foregroundStyle(.secondary)

            Text("Searching web for ")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                +
                Text(query)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: Private

    private let query: String
}
