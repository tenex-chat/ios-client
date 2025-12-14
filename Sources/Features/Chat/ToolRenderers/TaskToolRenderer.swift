//
// TaskToolRenderer.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import SwiftUI

// MARK: - TaskToolRenderer

/// Renderer for Task tool calls (subagent spawning)
public struct TaskToolRenderer: View {
    // MARK: Lifecycle

    public init(description: String?, subagentType: String?) {
        self.description = description
        self.subagentType = subagentType
    }

    // MARK: Public

    public var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.triangle.branch")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)

            Text(displayText)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: Private

    private let description: String?
    private let subagentType: String?

    private var displayText: AttributedString {
        var text = AttributedString("Spawning ")

        if let subagentType, !subagentType.isEmpty {
            var typeAttr = AttributedString(subagentType)
            typeAttr.font = .system(size: 12, design: .monospaced)
            text.append(typeAttr)
            text.append(AttributedString(" agent"))
        } else {
            text.append(AttributedString("agent"))
        }

        if let description, !description.isEmpty {
            text.append(AttributedString(": \(description)"))
        }

        return text
    }
}
