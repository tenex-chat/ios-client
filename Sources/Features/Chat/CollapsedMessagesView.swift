//
// CollapsedMessagesView.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import SwiftUI
import TENEXCore

/// View that displays a collapsed summary of multiple consecutive messages
public struct CollapsedMessagesView: View {
    // MARK: Lifecycle

    /// Initialize the collapsed messages view
    /// - Parameters:
    ///   - messages: The messages that are collapsed
    ///   - isExpanded: Binding to control expanded state
    public init(messages: [Message], isExpanded: Binding<Bool>) {
        self.messages = messages
        self._isExpanded = isExpanded
    }

    // MARK: Public

    public var body: some View {
        Button {
            withAnimation {
                self.isExpanded.toggle()
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: self.isExpanded ? "chevron.down" : "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("\(self.messages.count) message\(self.messages.count == 1 ? "" : "s") collapsed")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        #if os(iOS)
            .background(Color(uiColor: .systemGray6))
        #else
            .background(Color(nsColor: .controlBackgroundColor))
        #endif
    }

    // MARK: Private

    @Binding private var isExpanded: Bool

    private let messages: [Message]
}
