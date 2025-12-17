//
// CollapsedMessagesView.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import SwiftUI
import TENEXCore

/// View that displays a collapsed summary of multiple consecutive messages
/// Maintains the visual thread connection by using the same layout as MessageRow
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
            HStack(alignment: .top, spacing: 12) {
                self.threadColumnView
                self.collapsedContent
                Spacer()
            }
            .padding(.vertical, 2)
            .padding(.horizontal, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: Private

    @Binding private var isExpanded: Bool

    private let messages: [Message]

    /// Thread continuity column - matches MessageRow avatar column width
    private var threadColumnView: some View {
        VStack(spacing: 0) {
            // Line above
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 2)
                .frame(maxHeight: .infinity)
        }
        .frame(width: 36, height: 24)
    }

    private var collapsedContent: some View {
        HStack(spacing: 6) {
            Image(systemName: self.isExpanded ? "chevron.down" : "chevron.right")
                .font(.caption2)
                .foregroundStyle(.secondary)

            Text("\(self.messages.count) message\(self.messages.count == 1 ? "" : "s")")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("Click to expand")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}
