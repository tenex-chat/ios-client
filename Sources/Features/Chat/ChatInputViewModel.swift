//
// ChatInputViewModel.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation
import Observation

// MARK: - ChatInputViewModel

/// View model for chat input field
@MainActor
@Observable
public final class ChatInputViewModel {
    // MARK: Lifecycle

    /// Initialize the chat input view model
    public init() {}

    // MARK: Public

    /// The currently selected agent ID
    public private(set) var selectedAgent: String?

    /// The currently selected branch ID
    public private(set) var selectedBranch: String?

    /// Whether the send button should be enabled
    public private(set) var canSend = false

    /// The current input text
    public var inputText = "" {
        didSet {
            updateCanSend()
        }
    }

    /// Select an agent
    /// - Parameter agentId: The agent identifier
    public func selectAgent(_ agentID: String) {
        selectedAgent = agentID
    }

    /// Select a branch
    /// - Parameter branchId: The branch identifier
    public func selectBranch(_ branchID: String) {
        selectedBranch = branchID
    }

    /// Clear the input text
    public func clearInput() {
        inputText = ""
    }

    // MARK: Private

    private func updateCanSend() {
        canSend = !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
