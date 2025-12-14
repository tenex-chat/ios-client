//
// MessageContentView.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import SwiftUI
import TENEXCore

// MARK: - MessageContentView

/// View for rendering message content with markdown and code blocks
public struct MessageContentView: View {
    // MARK: Public

    public var body: some View {
        Group {
            if message.isReasoning {
                ReasoningBlockView(message: message)
            } else if let toolCall = message.toolCall {
                ToolCallView(toolCall: toolCall)
            } else if message.isStreaming {
                streamingContent
            } else if message.content.contains("```") {
                codeBlockContent
            } else {
                Text(markdownText)
                    .font(.system(size: 16))
                    .lineSpacing(1.4)
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)
            }
        }
    }

    // MARK: Internal

    let message: Message

    // MARK: Private

    @State private var cursorVisible = false

    private var markdownText: AttributedString {
        do {
            return try AttributedString(markdown: message.content)
        } catch {
            return AttributedString(message.content)
        }
    }

    private var streamingContent: some View {
        HStack(alignment: .bottom, spacing: 2) {
            Text(markdownText)
                .font(.system(size: 16))
                .lineSpacing(1.4)
                .foregroundStyle(.primary)

            Rectangle()
                .fill(.primary)
                .frame(width: 2, height: 16)
                .opacity(cursorVisible ? 1 : 0)
                .onAppear {
                    withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                        cursorVisible = true
                    }
                }
        }
    }

    private var codeBlockContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(splitByCodeBlocks(), id: \.offset) { item in
                if item.isCode {
                    codeBlock(item.text)
                } else if !item.text.isEmpty {
                    Text(item.text)
                        .font(.system(size: 16))
                        .lineSpacing(1.4)
                        .foregroundStyle(.primary)
                }
            }
        }
        .textSelection(.enabled)
    }

    private func codeBlock(_ code: String) -> some View {
        Text(code)
            .font(.system(size: 13, design: .monospaced))
            .foregroundStyle(.primary)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(8)
    }

    private func splitByCodeBlocks() -> [(text: String, isCode: Bool, offset: Int)] {
        let pattern = "```[^`]*```"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else {
            return [(message.content, false, 0)]
        }

        let content = message.content
        let matches = regex.matches(in: content, range: NSRange(location: 0, length: content.utf16.count))

        var result: [(String, Bool, Int)] = []
        var lastIndex = content.startIndex

        for (offset, match) in matches.enumerated() {
            guard let matchRange = Range(match.range, in: content) else {
                continue
            }

            if lastIndex < matchRange.lowerBound {
                let text = String(content[lastIndex ..< matchRange.lowerBound])
                result.append((text, false, offset * 2))
            }

            let codeBlock = String(content[matchRange])
            let cleanCode = codeBlock
                .replacingOccurrences(of: "^```[a-zA-Z]*\n?", with: "", options: .regularExpression)
                .replacingOccurrences(of: "\n?```$", with: "", options: .regularExpression)
            result.append((cleanCode, true, offset * 2 + 1))

            lastIndex = matchRange.upperBound
        }

        if lastIndex < content.endIndex {
            let text = String(content[lastIndex ..< content.endIndex])
            result.append((text, false, matches.count * 2))
        }

        return result
    }
}
