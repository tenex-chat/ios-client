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
        NDKMarkdown(
            content: message.content,
            blockConfig: MarkdownBlockConfig(
                codeFont: .caption.monospaced()
            )
        )
        .textSelection(.enabled)
    }
}
