//
// SearchToolRenderer.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import SwiftUI

// MARK: - SearchToolRenderer

/// Renderer for Glob and Grep tool calls
public struct SearchToolRenderer: View {
    // MARK: Lifecycle

    public init(pattern: String) {
        self.pattern = pattern
    }

    // MARK: Public

    public var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)

            Text("Searching ")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                +
                Text(pattern)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: Private

    private let pattern: String
}
