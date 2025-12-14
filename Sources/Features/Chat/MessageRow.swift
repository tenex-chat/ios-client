//
// MessageRow.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import NDKSwiftCore
import NDKSwiftUI
import SwiftUI
import TENEXCore

// MARK: - MessageRow

/// View displaying a single message in Slack-style left-aligned layout
public struct MessageRow: View {
    // MARK: Lifecycle

    /// Initialize the message row
    /// - Parameters:
    ///   - message: The message to display
    ///   - currentUserPubkey: The current user's pubkey (to differentiate user vs agent)
    ///   - onReplyTap: Optional action when reply indicator is tapped
    ///   - onRetry: Optional action when retry button is tapped (for failed messages)
    ///   - onAgentTap: Optional action when agent avatar/name is tapped
    public init(
        message: Message,
        currentUserPubkey: String?,
        onReplyTap: (() -> Void)? = nil,
        onRetry: (() -> Void)? = nil,
        onAgentTap: (() -> Void)? = nil
    ) {
        self.message = message
        self.currentUserPubkey = currentUserPubkey
        self.onReplyTap = onReplyTap
        self.onRetry = onRetry
        self.onAgentTap = onAgentTap
        isAgent = currentUserPubkey != nil && message.pubkey != currentUserPubkey
    }

    // MARK: Public

    public var body: some View {
        HStack(alignment: .top, spacing: 12) {
            avatarView
            messageContentView
            Spacer()
        }
        .padding(.vertical, 8)
    }

    // MARK: Private

    @Environment(\.ndk) private var ndk
    @State private var cursorVisible = false

    private let message: Message
    private let currentUserPubkey: String?
    private let onReplyTap: (() -> Void)?
    private let onRetry: (() -> Void)?
    private let onAgentTap: (() -> Void)?
    private let isAgent: Bool

    private var markdownText: AttributedString {
        do {
            return try AttributedString(markdown: message.content)
        } catch {
            // Fallback to plain text if markdown parsing fails
            return AttributedString(message.content)
        }
    }

    private var avatarView: some View {
        Group {
            if isAgent, let onAgentTap {
                Button(action: onAgentTap) {
                    avatar
                }
                .buttonStyle(.plain)
            } else {
                avatar
            }
        }
    }

    private var avatar: some View {
        Image(systemName: "person.circle.fill")
            .font(.system(size: 36))
            .foregroundStyle(isAgent ? .blue : .gray)
    }

    private var messageContentView: some View {
        VStack(alignment: .leading, spacing: 4) {
            authorHeader
            messageContent

            if !isAgent, let status = message.status {
                statusIndicator(for: status)
            }

            if message.replyCount > 0, let onReplyTap {
                ReplyIndicatorView(
                    replyCount: message.replyCount,
                    authorPubkeys: message.replyAuthorPubkeys,
                    onTap: onReplyTap
                )
                .padding(.top, 4)
            }
        }
    }

    private var authorHeader: some View {
        HStack(spacing: 8) {
            if let ndk, isAgent {
                if let onAgentTap {
                    Button(action: onAgentTap) {
                        NDKUIUsername(ndk: ndk, pubkey: message.pubkey)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.blue)
                    }
                    .buttonStyle(.plain)
                } else {
                    NDKUIUsername(ndk: ndk, pubkey: message.pubkey)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.blue)
                }
            } else {
                Text("You")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)
            }

            Text(message.createdAt, style: .relative)
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)
        }
    }

    private var sendingStatusView: some View {
        HStack(spacing: 6) {
            ProgressView().scaleEffect(0.7)
            Text("Sending...").font(.caption).foregroundStyle(.secondary)
        }
    }

    private var sentStatusView: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark").font(.caption).foregroundStyle(.green)
            Text("Sent").font(.caption).foregroundStyle(.secondary)
        }
    }

    private var messageContent: some View {
        Group {
            if let toolCall = message.toolCall {
                // Tool call - render with specialized renderer
                ToolCallView(toolCall: toolCall)
            } else if message.isStreaming {
                // Streaming message with blinking cursor
                streamingContent
            } else if message.content.contains("```") {
                // Contains code blocks - render with special formatting
                codeBlockContent
            } else {
                // Regular markdown content
                Text(markdownText)
                    .font(.system(size: 16))
                    .lineSpacing(1.4)
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)
            }
        }
    }

    private var streamingContent: some View {
        HStack(alignment: .bottom, spacing: 2) {
            Text(markdownText)
                .font(.system(size: 16))
                .lineSpacing(1.4)
                .foregroundStyle(.primary)

            // Blinking cursor
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

    @ViewBuilder
    private func statusIndicator(for status: MessageStatus) -> some View {
        HStack(spacing: 6) {
            switch status {
            case .sending:
                sendingStatusView
            case .sent:
                sentStatusView
            case let .failed(error):
                failedStatusView(error: error)
            }
        }
        .padding(.top, 4)
    }

    private func failedStatusView(error: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill").font(.caption).foregroundStyle(.red)
            Text("Failed").font(.caption).foregroundStyle(.red)
            if let onRetry {
                Button { onRetry() } label: {
                    Text("Retry").font(.caption.bold()).foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
            }
            Text(error).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
        }
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
            // Convert NSRange to String.Index range
            guard let matchRange = Range(match.range, in: content) else {
                continue
            }

            // Add text before code block
            if lastIndex < matchRange.lowerBound {
                let text = String(content[lastIndex ..< matchRange.lowerBound])
                result.append((text, false, offset * 2))
            }

            // Add code block (remove ``` markers)
            let codeBlock = String(content[matchRange])
            let cleanCode = codeBlock
                .replacingOccurrences(of: "^```[a-zA-Z]*\n?", with: "", options: .regularExpression)
                .replacingOccurrences(of: "\n?```$", with: "", options: .regularExpression)
            result.append((cleanCode, true, offset * 2 + 1))

            lastIndex = matchRange.upperBound
        }

        // Add remaining text after last code block
        if lastIndex < content.endIndex {
            let text = String(content[lastIndex ..< content.endIndex])
            result.append((text, false, matches.count * 2))
        }

        return result
    }
}
