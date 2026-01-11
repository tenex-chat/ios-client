//
// AskQuestion.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation
import NDKSwiftCore

// MARK: - AskOption

/// Represents a single option in an ask question
public struct AskOption: Sendable, Identifiable {
    public let id: String
    public let label: String

    public init(id: String, label: String) {
        self.id = id
        self.label = label
    }
}

// MARK: - AskQuestion

/// Represents a single question in a multi-question ask event
/// Format: ["question", "ID", "Text", "Opt1", ...] or ["multiselect", "ID", "Text", "Opt1", ...]
public struct AskQuestion: Sendable, Identifiable {
    public let id: String
    public let question: String
    public let options: [AskOption]
    public let isMultiSelect: Bool

    public init(id: String, question: String, options: [AskOption], isMultiSelect: Bool) {
        self.id = id
        self.question = question
        self.options = options
        self.isMultiSelect = isMultiSelect
    }
}

// MARK: - AskQuestions

/// Container for multiple questions from an ask event
public struct AskQuestions: Sendable {
    public let questions: [AskQuestion]
    public let title: String?

    public var count: Int { questions.count }

    public init(questions: [AskQuestion], title: String?) {
        self.questions = questions
        self.title = title
    }

    /// Parse ask questions from an NDKEvent
    /// - Parameter event: The NDKEvent to parse
    /// - Returns: AskQuestions if the event contains question/multiselect tags, nil otherwise
    public static func from(event: NDKEvent) -> Self? {
        let questionTags = event.tags.filter { tag in
            guard let tagName = tag.first else {
                return false
            }
            return tagName == "question" || tagName == "multiselect"
        }

        guard !questionTags.isEmpty else {
            return nil
        }

        // Get the overall title from the title tag
        let titleTag = event.tags.first { $0.first == "title" }
        let title = titleTag?[safe: 1]

        let questions: [AskQuestion] = questionTags.compactMap { tag in
            guard let tagName = tag.first else {
                return nil
            }

            let isMultiSelect = tagName == "multiselect"
            let id = tag[safe: 1] ?? ""
            let questionText = tag[safe: 2] ?? ""

            // Options start at index 3
            let optionLabels = tag.count > 3 ? Array(tag[3...]) : []
            let options = optionLabels.enumerated().map { index, label in
                AskOption(id: "\(id)_opt_\(index)", label: label)
            }

            return AskQuestion(
                id: id,
                question: questionText,
                options: options,
                isMultiSelect: isMultiSelect
            )
        }

        return Self(questions: questions, title: title)
    }

    /// Checks if an event has the ask tag set to true
    /// Supports: ["ask", "true"], ["ask", "1"], or just ["ask"]
    public static func isAskEvent(_ event: NDKEvent) -> Bool {
        guard let askTag = event.tags.first(where: { $0.first == "ask" }) else {
            return false
        }
        // Accept ["ask"], ["ask", "true"], or ["ask", "1"]
        if askTag.count == 1 {
            return true
        }
        if let value = askTag[safe: 1] {
            return value == "true" || value == "1"
        }
        return false
    }

    /// Checks if an event has question/multiselect tags
    public static func hasQuestions(_ event: NDKEvent) -> Bool {
        event.tags.contains { tag in
            guard let tagName = tag.first else {
                return false
            }
            return tagName == "question" || tagName == "multiselect"
        }
    }

    /// Checks if an event is a multi-question ask event
    /// (has ask tag AND has question/multiselect tags)
    public static func isMultiQuestionAskEvent(_ event: NDKEvent) -> Bool {
        isAskEvent(event) && hasQuestions(event)
    }
}
