//
// CodebaseSearchToolRenderer.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import SwiftUI

// MARK: - CodebaseSearchToolRenderer

/// Renderer for codebase_search tool calls
public struct CodebaseSearchToolRenderer: View {
    // MARK: Lifecycle

    public init(query: String, searchType: String, fileType: String?) {
        self.query = query
        self.searchType = searchType
        self.fileType = fileType
    }

    // MARK: Public

    public var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)

            Text(displayText)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: Private

    private let query: String
    private let searchType: String
    private let fileType: String?

    private var displayText: AttributedString {
        var text = AttributedString("Searching codebase for ")

        var queryAttr = AttributedString(query)
        queryAttr.font = .system(size: 12, design: .monospaced)
        text.append(queryAttr)

        if let fileType, !fileType.isEmpty {
            text.append(AttributedString(" in "))
            var typeAttr = AttributedString(".\(fileType)")
            typeAttr.font = .system(size: 12, design: .monospaced)
            text.append(typeAttr)
            text.append(AttributedString(" files"))
        }

        text.append(AttributedString(" (\(searchType))"))

        return text
    }
}
