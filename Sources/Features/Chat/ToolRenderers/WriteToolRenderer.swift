//
// WriteToolRenderer.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import SwiftUI

// MARK: - WriteToolRenderer

/// Renderer for Write tool calls with expandable code preview
public struct WriteToolRenderer: View {
    // MARK: Lifecycle

    public init(displayPath: String, content: String) {
        self.displayPath = displayPath
        self.content = content
    }

    // MARK: Public

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            self.headerButton
            if self.expanded { self.expandedContent }
        }
    }

    // MARK: Private

    @State private var expanded = false

    private let displayPath: String
    private let content: String

    private var headerButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { self.expanded.toggle() }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: self.expanded ? "chevron.down" : "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Image(systemName: "pencil")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("Writing ").font(.subheadline).foregroundStyle(.secondary)
                    + Text(self.displayPath).font(.caption.monospaced()).foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
    }

    private var expandedContent: some View {
        ScrollView {
            Text(self.content)
                .font(.caption.monospaced())
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
        }
        .frame(maxHeight: 300)
        .background(Color.secondary.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.leading, 24)
    }
}
