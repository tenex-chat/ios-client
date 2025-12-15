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
            self.headerView

            // Content (only shown when expanded)
            if self.isExpanded {
                self.contentView
                    .padding(.top, 8)
            }
        }
        .padding(12)
        .background(self.message.isStreaming ? Color.blue.opacity(0.05) : Color.purple.opacity(0.05))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(self.message.isStreaming ? Color.blue.opacity(0.2) : Color.purple.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: Internal

    let message: Message

    // MARK: Private

    @State private var isExpanded = false
    @State private var cursorVisible = false

    private var markdownText: AttributedString {
        do {
            return try AttributedString(markdown: self.message.content)
        } catch {
            return AttributedString(self.message.content)
        }
    }

    private var headerView: some View {
        HStack(spacing: 8) {
            self.headerIcon
            self.headerTitle
            if self.message.isStreaming {
                self.streamingIndicator
            }
            Spacer()
            self.expandCollapseButton
        }
    }

    private var headerIcon: some View {
        Image(systemName: "lightbulb.fill")
            .foregroundStyle(Color.purple)
            .font(.subheadline)
    }

    private var headerTitle: some View {
        Text("AI Reasoning")
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.secondary)
    }

    private var streamingIndicator: some View {
        HStack(spacing: 4) {
            Text("thinking")
                .font(.caption)
                .foregroundStyle(.tertiary)

            HStack(spacing: 2) {
                ForEach(0 ..< 3) { index in
                    Circle()
                        .fill(Color.secondary)
                        .frame(width: 3, height: 3)
                        .opacity(self.cursorVisible ? 1 : 0.3)
                        .animation(
                            .easeInOut(duration: 0.6)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.2),
                            value: self.cursorVisible
                        )
                }
            }
        }
        .onAppear {
            self.cursorVisible = true
        }
    }

    private var expandCollapseButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                self.isExpanded.toggle()
            }
        } label: {
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .rotationEffect(.degrees(self.isExpanded ? 90 : 0))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(self.isExpanded ? "Collapse reasoning" : "Expand reasoning")
    }

    private var contentView: some View {
        VStack(alignment: .leading, spacing: 8) {
            if self.message.content.contains("```") {
                // Contains code blocks
                ForEach(self.splitByCodeBlocks(), id: \.offset) { item in
                    if item.isCode {
                        self.codeBlock(item.text)
                    } else if !item.text.isEmpty {
                        Text(item.text)
                            .font(.subheadline)
                            .lineSpacing(1.4)
                            .foregroundStyle(.primary)
                    }
                }
            } else {
                // Regular markdown content
                Text(self.markdownText)
                    .font(.subheadline)
                    .lineSpacing(1.4)
                    .foregroundStyle(.primary)
            }
        }
        .textSelection(.enabled)
    }

    private func codeBlock(_ code: String) -> some View {
        Text(code)
            .font(.caption.monospaced())
            .foregroundStyle(.primary)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(8)
    }

    private func splitByCodeBlocks() -> [(text: String, isCode: Bool, offset: Int)] {
        let pattern = "```[^`]*```"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else {
            return [(self.message.content, false, 0)]
        }

        let content = self.message.content
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
