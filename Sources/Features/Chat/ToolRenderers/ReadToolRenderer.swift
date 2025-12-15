//
// ReadToolRenderer.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import SwiftUI

// MARK: - ReadToolRenderer

/// Renderer for Read and Edit tool calls
public struct ReadToolRenderer: View {
    // MARK: Lifecycle

    public init(displayPath: String) {
        self.displayPath = displayPath
    }

    // MARK: Public

    public var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "doc.text")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("Reading ")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                +
                Text(self.displayPath)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
        }
    }

    // MARK: Private

    private let displayPath: String
}
