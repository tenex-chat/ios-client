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
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text(self.displayText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: Private

    private let delegations: [Delegation]
    private let mode: String

    private var recipients: [String] {
        self.delegations.compactMap(\.recipient).filter { !$0.isEmpty }
    }

    private var displayText: AttributedString {
        var text = AttributedString("Delegating to ")

        for (index, recipient) in self.recipients.enumerated() {
            var recipientAttr = AttributedString(recipient)
            recipientAttr.font = .caption.monospaced()
            text.append(recipientAttr)

            if index < self.recipients.count - 1 {
                text.append(AttributedString(", "))
            }
        }

        if self.mode != "wait" {
            text.append(AttributedString(" (\(self.mode))"))
        }

        return text
    }
}
