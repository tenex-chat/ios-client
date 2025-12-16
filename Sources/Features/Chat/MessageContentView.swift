//
// MessageContentView.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import NDKSwiftUI
import SwiftUI
import TENEXCore

// MARK: - MessageContentView

/// View for rendering message content with markdown and code blocks
public struct MessageContentView: View {
    // MARK: Public

    public var body: some View {
        Group {
            if self.message.isReasoning {
                ReasoningBlockView(message: self.message)
            } else if let toolCall = message.toolCall {
                ToolCallView(toolCall: toolCall)
            } else if self.message.isStreaming {
                self.streamingContent
            } else {
                NDKMarkdown(content: message.content)
                    .textSelection(.enabled)
            }
        }
    }

    // MARK: Internal

    let message: Message

    // MARK: Private

    @State private var cursorVisible = false

    private var streamingMarkdownText: AttributedString {
        do {
            return try AttributedString(markdown: self.message.content)
        } catch {
            return AttributedString(self.message.content)
        }
    }

    private var streamingContent: some View {
        HStack(alignment: .bottom, spacing: 2) {
            Text(self.streamingMarkdownText)
                .font(.callout)
                .lineSpacing(1.4)
                .foregroundStyle(.primary)

            Rectangle()
                .fill(.primary)
                .frame(width: 2, height: 16)
                .opacity(self.cursorVisible ? 1 : 0)
                .onAppear {
                    withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                        self.cursorVisible = true
                    }
                }
        }
    }
}
