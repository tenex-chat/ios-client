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
            headerButton
            if expanded { expandedContent }
        }
    }

    // MARK: Private

    @State private var expanded = false

    private let displayPath: String
    private let content: String

    private var headerButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: expanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Image(systemName: "pencil")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                Text("Writing ").font(.system(size: 14)).foregroundStyle(.secondary)
                    + Text(displayPath).font(.system(size: 12, design: .monospaced)).foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
    }

    private var expandedContent: some View {
        ScrollView {
            Text(content)
                .font(.system(size: 12, design: .monospaced))
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
