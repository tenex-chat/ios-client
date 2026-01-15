//
// AskToolRenderer.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import SwiftUI
import TENEXCore

// MARK: - AskToolRenderer

/// Renderer for ask tool calls - displays interactive ask questions UI
@MainActor
public struct AskToolRenderer: View {
    // MARK: Lifecycle

    public init(
        askQuestions: AskQuestions,
        isAnswered: Bool = false,
        answerContent: String? = nil,
        onAnswer: @escaping ([String: [String]]) -> Void
    ) {
        self.askQuestions = askQuestions
        self.isAnswered = isAnswered
        self.answerContent = answerContent
        self.onAnswer = onAnswer
    }

    // MARK: Public

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Overall title
            if let title = askQuestions.title {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
            }

            // Context/explanation
            if let context = askQuestions.context, !context.isEmpty {
                Text(context)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if isAnswered {
                answeredStateView
            } else {
                questionsView
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground).opacity(0.3))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.separator), lineWidth: 1)
        )
    }

    // MARK: Private

    private let askQuestions: AskQuestions
    private let isAnswered: Bool
    private let answerContent: String?
    private let onAnswer: ([String: [String]]) -> Void

    @State private var activeQuestionIndex = 0
    @State private var selections: [String: Set<String>] = [:]
    @State private var customInputs: [String: String] = [:]
    @State private var usingCustomInput: [String: Bool] = [:]

    private var answeredStateView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("Response submitted")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.green)
            }

            if let content = answerContent, !content.isEmpty {
                Text(content)
                    .font(.subheadline)
                    .padding(12)
                    .background(Color(.tertiarySystemBackground))
                    .cornerRadius(8)
            }
        }
    }

    @ViewBuilder
    private var questionsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Tab bar for multiple questions
            if askQuestions.count > 1 {
                tabBar
            }

            // Current question content
            if activeQuestionIndex < askQuestions.questions.count {
                let question = askQuestions.questions[activeQuestionIndex]
                questionContent(question, showID: askQuestions.count == 1)
            }

            // Submit button
            submitButton
        }
    }

    private var tabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(Array(askQuestions.questions.enumerated()), id: \.element.id) { index, question in
                    tabButton(
                        title: question.id.isEmpty ? "Question \(index + 1)" : question.id,
                        isSelected: activeQuestionIndex == index
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            activeQuestionIndex = index
                        }
                    }
                }
            }
        }
        .padding(.bottom, 4)
    }

    private func tabButton(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(isSelected ? .primary : .secondary)

                Rectangle()
                    .fill(isSelected ? Color.accentColor : .clear)
                    .frame(height: 2)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func questionContent(_ question: AskQuestion, showID: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Question header
            VStack(alignment: .leading, spacing: 4) {
                if showID, !question.id.isEmpty {
                    Text(question.id.uppercased())
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                        .tracking(0.5)
                }

                Text(question.question)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)

                if question.isMultiSelect {
                    Text("Select all that apply")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Options
            if !question.options.isEmpty {
                optionsGrid(question)
            }

            // Custom input
            customInputField(question)
        }
    }

    private func optionsGrid(_ question: AskQuestion) -> some View {
        FlowLayout(spacing: 6) {
            ForEach(question.options) { option in
                optionButton(option: option, question: question)
            }
        }
    }

    private func optionButton(option: AskOption, question: AskQuestion) -> some View {
        let isSelected = isOptionSelected(questionID: question.id, optionID: option.id)

        return Button {
            handleOptionSelect(questionID: question.id, optionID: option.id, isMultiSelect: question.isMultiSelect)
        } label: {
            HStack(spacing: 6) {
                if question.isMultiSelect {
                    Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                        .font(.subheadline)
                        .foregroundStyle(isSelected ? .white : .secondary.opacity(0.6))
                }

                Text(option.label)
                    .font(.subheadline)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color.accentColor : Color(.tertiarySystemBackground))
            .foregroundStyle(isSelected ? .white : .primary)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.accentColor : Color(.separator), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func customInputField(_ question: AskQuestion) -> some View {
        let isActive = usingCustomInput[question.id] == true && !(customInputs[question.id]?.isEmpty ?? true)

        return TextField(
            question.options.isEmpty ? "Type your answer..." : "Or type your own answer...",
            text: Binding(
                get: { customInputs[question.id] ?? "" },
                set: { handleCustomInputChange(questionID: question.id, value: $0) }
            )
        )
        .font(.subheadline)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(.tertiarySystemBackground))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isActive ? Color.accentColor : Color(.separator), lineWidth: isActive ? 2 : 1)
        )
        .onTapGesture {
            handleCustomInputFocus(questionID: question.id)
        }
    }

    private var submitButton: some View {
        HStack {
            Spacer()
            Button {
                handleSubmit()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "paperplane.fill")
                        .font(.subheadline)
                    Text("Send Response")
                        .font(.subheadline.weight(.medium))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(hasAnyResponse ? Color.accentColor : Color.accentColor.opacity(0.6))
                .foregroundStyle(.white)
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 8)
    }

    // MARK: - State Management

    private func isOptionSelected(questionID: String, optionID: String) -> Bool {
        guard usingCustomInput[questionID] != true else {
            return false
        }
        return selections[questionID]?.contains(optionID) ?? false
    }

    private func handleOptionSelect(questionID: String, optionID: String, isMultiSelect: Bool) {
        usingCustomInput[questionID] = false

        if isMultiSelect {
            var current = selections[questionID] ?? []
            if current.contains(optionID) {
                current.remove(optionID)
            } else {
                current.insert(optionID)
            }
            selections[questionID] = current
        } else {
            let current = selections[questionID]
            if current?.contains(optionID) == true {
                selections[questionID] = []
            } else {
                selections[questionID] = [optionID]
            }
        }
    }

    private func handleCustomInputFocus(questionID: String) {
        usingCustomInput[questionID] = true
        selections[questionID] = []
    }

    private func handleCustomInputChange(questionID: String, value: String) {
        customInputs[questionID] = value
        if !value.isEmpty {
            usingCustomInput[questionID] = true
            selections[questionID] = []
        }
    }

    private var hasAnyResponse: Bool {
        askQuestions.questions.contains { question in
            if let selected = selections[question.id], !selected.isEmpty {
                return true
            }
            if usingCustomInput[question.id] == true,
               let customText = customInputs[question.id],
               !customText.isEmpty {
                return true
            }
            return false
        }
    }

    private func handleSubmit() {
        var responses: [String: [String]] = [:]

        for question in askQuestions.questions {
            var answerValues: [String] = []

            if usingCustomInput[question.id] == true,
               let customText = customInputs[question.id],
               !customText.isEmpty {
                answerValues = [customText]
            } else if let selected = selections[question.id], !selected.isEmpty {
                answerValues = question.options
                    .filter { selected.contains($0.id) }
                    .map(\.label)
            }

            if !answerValues.isEmpty {
                responses[question.id] = answerValues
            }
        }

        if !responses.isEmpty {
            onAnswer(responses)
        }
    }
}

// MARK: - FlowLayout

/// A layout that arranges views in a flowing grid, wrapping to new lines as needed
private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) -> CGSize {
        let result = layout(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) {
        let result = layout(proposal: proposal, subviews: subviews)

        for (index, placement) in result.placements.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + placement.x, y: bounds.minY + placement.y),
                proposal: ProposedViewSize(placement.size)
            )
        }
    }

    private struct LayoutResult {
        var size: CGSize
        var placements: [(x: CGFloat, y: CGFloat, size: CGSize)]
    }

    private func layout(proposal: ProposedViewSize, subviews: Subviews) -> LayoutResult {
        let maxWidth = proposal.width ?? .infinity

        var placements: [(x: CGFloat, y: CGFloat, size: CGSize)] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var totalWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if currentX + size.width > maxWidth, currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }

            placements.append((x: currentX, y: currentY, size: size))

            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
            totalWidth = max(totalWidth, currentX - spacing)
        }

        totalHeight = currentY + lineHeight

        return LayoutResult(
            size: CGSize(width: totalWidth, height: totalHeight),
            placements: placements
        )
    }
}
