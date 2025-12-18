//
// ToolGroupView.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import SwiftUI
import TENEXCore

// MARK: - ToolGroupView

/// View for displaying a group of tool calls with optional thinking blocks
public struct ToolGroupView: View {
    // MARK: Lifecycle

    public init(
        group: ToolGroupItem,
        isConsecutive: Bool = false,
        hasNextConsecutive: Bool = false
    ) {
        self.group = group
        self.isConsecutive = isConsecutive
        self.hasNextConsecutive = hasNextConsecutive
    }

    // MARK: Public

    public var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Avatar column with continuous border line
            self.avatarColumn

            // Tool group content
            self.toolGroupContent
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }

    // MARK: Private

    private let group: ToolGroupItem
    private let isConsecutive: Bool
    private let hasNextConsecutive: Bool

    @State private var isExpanded = false
    @State private var expandedToolIDs: Set<String> = []

    private var displayText: String {
        ToolDisplayUtils.getGroupDisplayText(toolCalls: self.group.toolCalls, isActive: self.group.isActive)
    }

    private var groupIconName: String {
        ToolDisplayUtils.getGroupIconName(toolCalls: self.group.toolCalls)
    }

    private var showExpandButton: Bool {
        self.group.tools.count > 1 || self.group.hasThinking
    }

    @ViewBuilder
    private var avatarColumn: some View {
        ZStack {
            // Continuous border line
            if self.isConsecutive || self.hasNextConsecutive {
                Rectangle()
                    .fill(Color.secondary.opacity(0.3))
                    .frame(width: 1)
            }

            // Dot indicator for consecutive messages
            if self.isConsecutive {
                Circle()
                    .fill(Color.secondary.opacity(0.6))
                    .frame(width: 6, height: 6)
            }
        }
        .frame(width: 36)
    }

    @ViewBuilder
    private var toolGroupContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            if self.showExpandButton {
                // Multiple tools or has thinking: collapsible group
                self.collapsibleHeader
            } else {
                // Single tool without thinking: inline display
                self.inlineDisplay
            }

            // Expanded content
            if self.isExpanded {
                self.expandedContent
            }
        }
    }

    @ViewBuilder
    private var inlineDisplay: some View {
        HStack(spacing: 6) {
            Image(systemName: self.groupIconName)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(self.displayText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var collapsibleHeader: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                self.isExpanded.toggle()
            }
        } label: {
            HStack(spacing: 6) {
                // Chevron
                Image(systemName: self.isExpanded ? "chevron.down" : "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                // Brain icon if has thinking
                if self.group.hasThinking {
                    Image(systemName: "brain")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Tool category icon
                Image(systemName: self.groupIconName)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                // Display text
                Text(self.displayText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Render thinking blocks first
            ForEach(self.group.thinking, id: \.id) { thinkingMessage in
                ReasoningBlockView(message: thinkingMessage)
                    .padding(.leading, 16)
            }

            // Render individual tools
            ForEach(self.group.tools, id: \.id) { toolMessage in
                if let toolCall = toolMessage.toolCall {
                    self.individualToolView(toolMessage: toolMessage, toolCall: toolCall)
                }
            }
        }
        .padding(.leading, 16)
    }

    @ViewBuilder
    private func individualToolView(toolMessage: Message, toolCall: ToolCall) -> some View {
        let isToolExpanded = self.expandedToolIDs.contains(toolMessage.id)
        let action = ToolDisplayUtils.getActionInfo(for: toolCall)
        let iconName = ToolDisplayUtils.getIconName(for: action.category)
        let displayText = ToolDisplayUtils.getIndividualDisplayText(for: toolCall)

        VStack(alignment: .leading, spacing: 4) {
            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    if isToolExpanded {
                        self.expandedToolIDs.remove(toolMessage.id)
                    } else {
                        self.expandedToolIDs.insert(toolMessage.id)
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    // Chevron for expandable args
                    Image(systemName: isToolExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)

                    // Tool icon
                    Image(systemName: iconName)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    // Display text
                    Text(displayText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)

            // Expanded args JSON
            if isToolExpanded {
                self.toolArgsView(toolCall: toolCall)
            }
        }
    }

    @ViewBuilder
    private func toolArgsView(toolCall: ToolCall) -> some View {
        let argsJSON = formatArgsAsJSON(toolCall.args)

        Text(argsJSON)
            .font(.system(size: 11, design: .monospaced))
            .foregroundStyle(.secondary)
            .padding(8)
            .background(Color.secondary.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .padding(.leading, 20)
    }

    private func formatArgsAsJSON(_ args: [String: AnySendable]) -> String {
        // Convert to JSON-serializable dictionary
        let jsonDict = args.reduce(into: [String: Any]()) { result, pair in
            result[pair.key] = pair.value.value
        }

        guard let data = try? JSONSerialization.data(withJSONObject: jsonDict, options: [.prettyPrinted, .sortedKeys]),
              let jsonString = String(data: data, encoding: .utf8)
        else {
            return "{}"
        }

        return jsonString
    }
}
