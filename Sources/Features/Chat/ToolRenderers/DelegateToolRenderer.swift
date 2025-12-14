//
// DelegateToolRenderer.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import SwiftUI
import TENEXCore

// MARK: - DelegateToolRenderer

/// Renderer for delegate tool calls
public struct DelegateToolRenderer: View {
    // MARK: Lifecycle

    public init(delegations: [Delegation], mode: String) {
        self.delegations = delegations
        self.mode = mode
    }

    // MARK: Public

    public var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "person.2")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)

            Text(displayText)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: Private

    private let delegations: [Delegation]
    private let mode: String

    private var recipients: [String] {
        delegations.compactMap(\.recipient).filter { !$0.isEmpty }
    }

    private var displayText: AttributedString {
        var text = AttributedString("Delegating to ")

        for (index, recipient) in recipients.enumerated() {
            var recipientAttr = AttributedString(recipient)
            recipientAttr.font = .system(size: 12, design: .monospaced)
            text.append(recipientAttr)

            if index < recipients.count - 1 {
                text.append(AttributedString(", "))
            }
        }

        if mode != "wait" {
            text.append(AttributedString(" (\(mode))"))
        }

        return text
    }
}
