//
// ReasoningBlockView.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import NDKSwiftUI
import SwiftUI
import TENEXCore

/// View for rendering AI reasoning/thinking content in a collapsible block
public struct ReasoningBlockView: View {
    // MARK: Public

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header - clickable to expand/collapse
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    self.isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 4) {
                    Text("Thinking")
                        .font(.caption)
                        .foregroundStyle(.tertiary)

                    if self.message.isStreaming {
                        self.streamingIndicator
                    }

                    // Subtle chevron for discoverability
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.quaternary)
                        .rotationEffect(.degrees(self.isExpanded ? 90 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(self.isExpanded ? "Collapse thinking" : "Expand thinking")
            .accessibilityHint("Shows AI reasoning process")

            // Content (only shown when expanded)
            if self.isExpanded {
                self.contentView
                    .padding(.top, 8)
            }
        }
    }

    // MARK: Internal

    let message: Message

    // MARK: Private

    @State private var isExpanded = false
    @State private var cursorVisible = false

    private var streamingIndicator: some View {
        HStack(spacing: 2) {
            ForEach(0 ..< 3) { index in
                Circle()
                    .fill(Color.secondary.opacity(0.5))
                    .frame(width: 2, height: 2)
                    .opacity(self.cursorVisible ? 1 : 0.3)
                    .animation(
                        .easeInOut(duration: 0.6)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.2),
                        value: self.cursorVisible
                    )
            }
        }
        .onAppear {
            self.cursorVisible = true
        }
    }

    private var contentView: some View {
        NDKMarkdown(
            content: message.content,
            blockConfig: MarkdownBlockConfig(
                codeFont: .caption.monospaced()
            )
        )
        .textSelection(.enabled)
    }
}
