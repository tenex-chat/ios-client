//
// MessageContentView.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import NDKSwiftUI
import SwiftUI
import TENEXCore

// MARK: - URL Identifiable Extension

extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}

// MARK: - MessageContentView

/// View for rendering message content with markdown and code blocks
public struct MessageContentView: View {
    // MARK: Lifecycle

    public init(
        message: Message,
        isAskAnswered: Bool = false,
        askAnswerContent: String? = nil,
        onAskAnswer: (([String: [String]]) -> Void)? = nil
    ) {
        self.message = message
        self.isAskAnswered = isAskAnswered
        self.askAnswerContent = askAnswerContent
        self.onAskAnswer = onAskAnswer
    }

    // MARK: Public

    public var body: some View {
        Group {
            if self.message.isReasoning {
                ReasoningBlockView(message: self.message)
            } else if let toolCall = message.toolCall, toolCall.name == "ask",
                      let askQuestions = toolCall.askQuestions() {
                // Ask tool call - render interactive ask UI
                AskToolRenderer(
                    askQuestions: askQuestions,
                    isAnswered: self.isAskAnswered,
                    answerContent: self.askAnswerContent,
                    onAnswer: self.onAskAnswer ?? { _ in }
                )
            } else if let toolCall = message.toolCall {
                ToolCallView(toolCall: toolCall)
            } else if self.message.isAskEvent {
                AskEventView(
                    message: self.message,
                    isAnswered: self.isAskAnswered,
                    answerContent: self.askAnswerContent,
                    onAnswer: self.onAskAnswer ?? { _ in }
                )
            } else if self.message.isStreaming {
                self.streamingContent
            } else {
                NDKMarkdown(content: message.content)
                    .textSelection(.enabled)
                    .onImageTap { url, _ in
                        self.selectedImageURL = url
                    }
            }
        }
        #if os(iOS)
        .fullScreenCover(item: $selectedImageURL) { url in
            ImageLightboxView(url: url, isPresented: Binding(
                get: { self.selectedImageURL != nil },
                set: { if !$0 { self.selectedImageURL = nil } }
            ))
        }
        #else
        .sheet(item: $selectedImageURL) { url in
            ImageLightboxView(url: url, isPresented: Binding(
                get: { self.selectedImageURL != nil },
                set: { if !$0 { self.selectedImageURL = nil } }
            ))
            .frame(minWidth: 600, minHeight: 400)
        }
        #endif
    }

    // MARK: Internal

    let message: Message
    let isAskAnswered: Bool
    let askAnswerContent: String?
    let onAskAnswer: (([String: [String]]) -> Void)?

    // MARK: Private

    @State private var cursorVisible = false
    @State private var selectedImageURL: URL?

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
