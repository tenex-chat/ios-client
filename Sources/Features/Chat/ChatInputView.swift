//
// ChatInputView.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import NDKSwiftCore
import SwiftUI
import TENEXCore

#if os(iOS)
    import UIKit
#else
    import AppKit
#endif

// MARK: - Platform Colors

private extension Color {
    static var platformBackground: Color {
        #if os(iOS)
            Color(uiColor: .systemBackground)
        #else
            Color(nsColor: .windowBackgroundColor)
        #endif
    }

    static var platformSecondaryBackground: Color {
        #if os(iOS)
            Color(uiColor: .secondarySystemBackground)
        #else
            Color(nsColor: .controlBackgroundColor)
        #endif
    }

    static var platformSeparator: Color {
        #if os(iOS)
            Color(uiColor: .separator)
        #else
            Color(nsColor: .separatorColor)
        #endif
    }
}

// MARK: - ChatInputView

/// Multi-line text input for composing chat messages
/// Integrates AgentSelector, MentionAutocomplete, Nudges, and Branch selection
public struct ChatInputView: View {
    // MARK: Lifecycle

    /// Initialize the chat input view
    /// - Parameters:
    ///   - viewModel: The input view model
    ///   - dataStore: DataStore for nudges and agents
    ///   - ndk: The NDK instance for profile pictures
    ///   - projectReference: The project reference for agent config
    ///   - defaultAgentPubkey: Optional default agent pubkey (e.g., most recent message author)
    ///   - onSend: Callback when message is sent
    public init(
        viewModel: ChatInputViewModel,
        dataStore: DataStore,
        ndk: NDK,
        projectReference: String,
        defaultAgentPubkey: String? = nil,
        onSend: @escaping (String, String?, [String]) -> Void
    ) {
        self.ndk = ndk
        self.dataStore = dataStore
        self.projectReference = projectReference
        self.onSend = onSend
        _viewModel = State(initialValue: viewModel)
        _agentSelectorVM = State(initialValue: AgentSelectorViewModel(
            dataStore: dataStore,
            projectReference: projectReference,
            defaultAgentPubkey: defaultAgentPubkey
        ))
        _mentionVM = State(initialValue: MentionAutocompleteViewModel(
            dataStore: dataStore,
            projectReference: projectReference
        ))
    }

    // MARK: Public

    public var body: some View {
        VStack(spacing: 0) {
            self.replyContextView
            self.nudgesPillsView
            self.mentionAutocompleteView
            self.mainInputArea
        }
        .onChange(of: self.viewModel.inputText) { _, newValue in
            self.handleTextChange(newValue)
        }
        .onChange(of: self.agentSelectorVM.selectedAgentPubkey) { _, newPubkey in
            self.handleAgentSelection(newPubkey)
        }
        .sheet(isPresented: self.$showNudgeSelector) {
            NudgeSelectorSheet(
                selectedNudges: self.$viewModel.selectedNudges,
                availableNudges: self.dataStore.nudges
            )
        }
        .sheet(isPresented: self.$showBranchSelector) {
            BranchSelectorSheet(
                selectedBranch: self.$viewModel.selectedBranch,
                availableBranches: self.availableBranches,
                defaultBranch: self.defaultBranch
            )
        }
        .sheet(isPresented: self.$showAgentConfig) {
            if let agent = agentSelectorVM.selectedAgentPubkey.flatMap({ pubkey in
                agentSelectorVM.agents.first(where: { $0.pubkey == pubkey })
            }) {
                AgentConfigSheet(
                    isPresented: self.$showAgentConfig,
                    agent: agent,
                    availableModels: self.availableModels,
                    availableTools: self.availableTools,
                    projectReference: self.projectReference,
                    ndk: self.ndk
                )
            }
        }
    }

    // MARK: Private

    @State private var viewModel: ChatInputViewModel
    @State private var agentSelectorVM: AgentSelectorViewModel
    @State private var mentionVM: MentionAutocompleteViewModel
    @State private var showNudgeSelector = false
    @State private var showBranchSelector = false
    @State private var showAgentConfig = false
    @FocusState private var isInputFocused: Bool

    /// Dynamic Type scaling for send button
    @ScaledMetric(relativeTo: .body) private var sendButtonSize: CGFloat = 32
    @ScaledMetric(relativeTo: .body) private var sendIconSize: CGFloat = 14

    /// Reduce Motion accessibility setting
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let ndk: NDK
    private let dataStore: DataStore
    private let projectReference: String
    private let onSend: (String, String?, [String]) -> Void

    /// Available models from project status
    private var availableModels: [String] {
        self.dataStore.getProjectStatus(projectCoordinate: self.projectReference)
            .map { Array(Set($0.agents.compactMap(\.model))).sorted() } ?? []
    }

    /// Available tools from project status
    private var availableTools: [String] {
        self.dataStore.getProjectStatus(projectCoordinate: self.projectReference)
            .map { Array(Set($0.agents.flatMap(\.tools))).sorted() } ?? []
    }

    /// Available branches from project status
    private var availableBranches: [String] {
        self.dataStore.getProjectStatus(projectCoordinate: self.projectReference)?.branches.sorted() ?? []
    }

    /// Default branch from project status (first branch in array)
    private var defaultBranch: String? {
        self.dataStore.getProjectStatus(projectCoordinate: self.projectReference)?.defaultBranch
    }

    /// The branch to display (selected branch or default branch)
    private var displayBranch: String? {
        self.viewModel.selectedBranch ?? self.defaultBranch
    }

    // MARK: - View Components

    @ViewBuilder private var replyContextView: some View {
        if let replyTo = viewModel.replyToMessage {
            ReplyContextBanner(message: replyTo) {
                self.viewModel.clearReplyTo()
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
    }

    @ViewBuilder private var nudgesPillsView: some View {
        if !self.viewModel.selectedNudges.isEmpty {
            SelectedNudgesPills(
                selectedNudges: self.viewModel.selectedNudges,
                availableNudges: self.dataStore.nudges
            ) { self.viewModel.toggleNudge($0) }
                .padding(.vertical, 8)
        }
    }

    @ViewBuilder private var mentionAutocompleteView: some View {
        if self.mentionVM.isVisible {
            MentionAutocompleteView(viewModel: self.mentionVM, ndk: self.ndk) { replacement, pubkey in
                self.handleMentionSelection(replacement: replacement, pubkey: pubkey)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
    }

    private var mainInputArea: some View {
        VStack(spacing: 12) {
            self.controlsRow

            if self.viewModel.isExpanded {
                self.expandedInputBar
            } else {
                self.compactInputBar
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.platformBackground)
    }

    // MARK: - Controls Row

    private var controlsRow: some View {
        HStack(spacing: 8) {
            self.nudgeButton
            AgentSelectorButton(viewModel: self.agentSelectorVM)
            self.branchButton
            Spacer()
            self.expandButton
        }
    }

    private var nudgeButton: some View {
        Button {
            self.showNudgeSelector = true
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "square.slash")
                    .font(.subheadline)
                if !self.viewModel.selectedNudges.isEmpty {
                    Text("\(self.viewModel.selectedNudges.count)")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue)
                        .clipShape(Circle())
                }
            }
            .foregroundStyle(.primary)
        }
        .buttonStyle(.plain)
    }

    private var branchButton: some View {
        Button {
            self.showBranchSelector = true
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "arrow.branch")
                    .font(.subheadline)
                if let branch = displayBranch {
                    Text(branch)
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }
            .foregroundStyle(self.displayBranch != nil ? .green : .primary)
        }
        .buttonStyle(.plain)
    }

    private var expandButton: some View {
        Button {
            self.viewModel.setExpanded(!self.viewModel.isExpanded)
        } label: {
            Image(systemName: self.viewModel.isExpanded ? "chevron.down" : "chevron.up")
                .font(.subheadline)
                .foregroundStyle(.primary)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Input Bars

    private var compactInputBar: some View {
        HStack(alignment: .bottom, spacing: 8) {
            ZStack(alignment: .leading) {
                if self.viewModel.inputText.isEmpty {
                    Text("Message...")
                        .font(.callout)
                        .foregroundStyle(.tertiary)
                        .padding(.leading, 4)
                }
                TextEditor(text: self.$viewModel.inputText)
                    .font(.callout)
                    .scrollContentBackground(.hidden)
                    .background(.clear)
                    .focused(self.$isInputFocused)
                    .frame(minHeight: 36, maxHeight: 120)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 4)

            self.sendButton
        }
        .padding(.leading, 16)
        .padding(.trailing, 6)
        .padding(.vertical, 6)
        .background(Color.platformSecondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }

    private var expandedInputBar: some View {
        VStack(spacing: 8) {
            TextEditor(text: self.$viewModel.inputText)
                .font(.system(.body, design: .monospaced))
                .scrollContentBackground(.hidden)
                .background(Color.platformSecondaryBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .frame(minHeight: 200, maxHeight: 400)
                .focused(self.$isInputFocused)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                )
                .accessibilityLabel("Message input")
                .accessibilityHint("Enter your message here")

            HStack {
                Text("Cmd+Enter to send")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                self.sendButton
            }
        }
    }

    private var sendButton: some View {
        Button {
            self.sendMessage()
        } label: {
            Image(systemName: "arrow.up")
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(self.viewModel.canSend ? Color.accentColor : Color.gray.opacity(0.4))
                )
        }
        .buttonStyle(.plain)
        .disabled(!self.viewModel.canSend)
        .animation(self.reduceMotion ? nil : .easeInOut(duration: 0.15), value: self.viewModel.canSend)
        #if os(macOS)
            .keyboardShortcut(.return, modifiers: .command)
        #endif
        #if os(iOS)
        .hoverEffect(.lift)
        #endif
        .accessibilityLabel("Send message")
        .accessibilityHint(self.viewModel.canSend ? "Double tap to send" : "Enter a message first")
    }

    private func sendMessage() {
        let text = self.viewModel.inputText
        let agentPubkey = self.agentSelectorVM.selectedAgentPubkey
        let mentions = self.viewModel.mentionedPubkeys
        self.onSend(text, agentPubkey, mentions)
        self.viewModel.clearInput()
    }

    private func handleTextChange(_ newText: String) {
        self.mentionVM.updateInput(text: newText, cursorPosition: newText.count)

        // Auto-expand when text > 300 chars
        if newText.count > 300, !self.viewModel.isExpanded {
            self.viewModel.setExpanded(true)
        }
    }

    private func handleAgentSelection(_ pubkey: String?) {
        if let pubkey {
            self.viewModel.selectAgent(pubkey)
        }
    }

    private func handleMentionSelection(replacement: String, pubkey: String) {
        self.viewModel.insertMention(replacement: replacement, pubkey: pubkey)
        self.mentionVM.hide()
    }
}
