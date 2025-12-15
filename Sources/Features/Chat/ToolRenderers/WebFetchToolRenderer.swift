//
// WebFetchToolRenderer.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import SwiftUI

// MARK: - WebFetchToolRenderer

/// Renderer for WebFetch tool calls
public struct WebFetchToolRenderer: View {
    // MARK: Lifecycle

    public init(url: String) {
        self.url = url
    }

    // MARK: Public

    public var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.down.doc")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("Fetching ")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                +
                Text(self.truncatedURL)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
        }
    }

    // MARK: Private

    private let url: String

    private var truncatedURL: String {
        let maxLength = 60
        if self.url.count <= maxLength {
            return self.url
        }
        return String(self.url.prefix(maxLength)) + "..."
    }
}
