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
                .font(.system(size: 14))
                .foregroundStyle(.secondary)

            Text("Fetching ")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                +
                Text(truncatedURL)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: Private

    private let url: String

    private var truncatedURL: String {
        let maxLength = 60
        if url.count <= maxLength {
            return url
        }
        return String(url.prefix(maxLength)) + "..."
    }
}
