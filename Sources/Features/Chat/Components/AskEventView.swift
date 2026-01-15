//
// AskEventView.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import NDKSwiftUI
import SwiftUI
import TENEXCore

// MARK: - AskEventView

/// View that displays ask questions with option selection
@MainActor
public struct AskEventView: View {
    // MARK: Lifecycle

    public init(
        message: Message,
        isAnswered: Bool = false,
        answerContent: String? = nil,
        onAnswer: @escaping ([String: [String]]) -> Void
    ) {
        self.message = message
        self.isAnswered = isAnswered
        self.answerContent = answerContent
        self.onAnswer = onAnswer
    }

    // MARK: Public

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let questions = message.askQuestions {
                // Overall title
                if let title = questions.title {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                }

                // Content/explanation
                if !message.content.isEmpty {
                    NDKMarkdown(content: message.content)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if isAnswered {
                    answeredStateView
                } else {
                    questionsView(questions)
                }
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

    private let message: Message
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
                NDKMarkdown(content: content)
                    .padding(12)
                    .background(Color(.tertiarySystemBackground))
                    .cornerRadius(8)
            }
        }
    }

    @ViewBuilder
    private func questionsView(_ questions: AskQuestions) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Tab bar for multiple questions
            if questions.count > 1 {
                tabBar(questions: questions)
            }

            // Current question content
            if activeQuestionIndex < questions.questions.count {
                let question = questions.questions[activeQuestionIndex]
                questionContent(question, showID: questions.count == 1)
            }

            // Submit button
            submitButton
        }
    }

    private func tabBar(questions: AskQuestions) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(Array(questions.questions.enumerated()), id: \.element.id) { index, question in
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
        // Disable custom input mode when selecting an option
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
            // Single selection - toggle off if clicking same option
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
        // Clear option selections when using custom input
        selections[questionID] = []
    }

    private func handleCustomInputChange(questionID: String, value: String) {
        customInputs[questionID] = value
        if usingCustomInput[questionID] == true {
            // Mark that we're actively using custom input
            if !value.isEmpty {
                selections[questionID] = []
            }
        }
    }

    private var hasAnyResponse: Bool {
        guard let questions = message.askQuestions else {
            return false
        }

        return questions.questions.contains { question in
            // Check for option selections
            if let selected = selections[question.id], !selected.isEmpty {
                return true
            }
            // Check for custom input
            if usingCustomInput[question.id] == true,
               let customText = customInputs[question.id],
               !customText.isEmpty {
                return true
            }
            return false
        }
    }

    private func handleSubmit() {
        guard let questions = message.askQuestions else {
            return
        }

        var responses: [String: [String]] = [:]

        for question in questions.questions {
            var answerValues: [String] = []

            // If using custom input, use that
            if usingCustomInput[question.id] == true,
               let customText = customInputs[question.id],
               !customText.isEmpty {
                answerValues = [customText]
            }
            // Otherwise use selected options
            else if let selected = selections[question.id], !selected.isEmpty {
                // Map option IDs back to labels
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
