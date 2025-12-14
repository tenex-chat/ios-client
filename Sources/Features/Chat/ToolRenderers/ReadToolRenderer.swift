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
                .font(.system(size: 14))
                .foregroundStyle(.secondary)

            Text("Reading ")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                +
                Text(displayPath)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: Private

    private let displayPath: String
}
