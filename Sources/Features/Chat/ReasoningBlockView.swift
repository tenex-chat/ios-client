//
// ReasoningBlockView.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import SwiftUI
import TENEXCore

/// View for rendering AI reasoning/thinking content in a collapsible block
public struct ReasoningBlockView: View {
    // MARK: Public

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with icon, title, and expand/collapse button
            headerView

            // Content (only shown when expanded)
            if isExpanded {
                contentView
                    .padding(.top, 8)
            }
        }
        .padding(12)
        .background(message.isStreaming ? Color.blue.opacity(0.05) : Color.purple.opacity(0.05))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(message.isStreaming ? Color.blue.opacity(0.2) : Color.purple.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: Internal

    let message: Message

    // MARK: Private

    @State private var isExpanded = false
    @State private var cursorVisible = false

    private var markdownText: AttributedString {
        do {
            return try AttributedString(markdown: message.content)
        } catch {
            return AttributedString(message.content)
        }
    }

    private var headerView: some View {
        HStack(spacing: 8) {
            headerIcon
            headerTitle
            if message.isStreaming {
                streamingIndicator
            }
            Spacer()
            expandCollapseButton
        }
    }

    private var headerIcon: some View {
        Image(systemName: "lightbulb.fill")
            .foregroundStyle(Color.purple)
            .font(.system(size: 14))
    }

    private var headerTitle: some View {
        Text("AI Reasoning")
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(.secondary)
    }

    private var streamingIndicator: some View {
        HStack(spacing: 4) {
            Text("thinking")
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)

            HStack(spacing: 2) {
                ForEach(0 ..< 3) { index in
                    Circle()
                        .fill(Color.secondary)
                        .frame(width: 3, height: 3)
                        .opacity(cursorVisible ? 1 : 0.3)
                        .animation(
                            .easeInOut(duration: 0.6)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.2),
                            value: cursorVisible
                        )
                }
            }
        }
        .onAppear {
            cursorVisible = true
        }
    }

    private var expandCollapseButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                isExpanded.toggle()
            }
        } label: {
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .rotationEffect(.degrees(isExpanded ? 90 : 0))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isExpanded ? "Collapse reasoning" : "Expand reasoning")
    }

    private var contentView: some View {
        VStack(alignment: .leading, spacing: 8) {
            if message.content.contains("```") {
                // Contains code blocks
                ForEach(splitByCodeBlocks(), id: \.offset) { item in
                    if item.isCode {
                        codeBlock(item.text)
                    } else if !item.text.isEmpty {
                        Text(item.text)
                            .font(.system(size: 14))
                            .lineSpacing(1.4)
                            .foregroundStyle(.primary)
                    }
                }
            } else {
                // Regular markdown content
                Text(markdownText)
                    .font(.system(size: 14))
                    .lineSpacing(1.4)
                    .foregroundStyle(.primary)
            }
        }
        .textSelection(.enabled)
    }

    private func codeBlock(_ code: String) -> some View {
        Text(code)
            .font(.system(size: 12, design: .monospaced))
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
