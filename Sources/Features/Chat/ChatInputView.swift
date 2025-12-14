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
    ///   - availableModels: Available models for agent config
    ///   - availableTools: Available tools for agent config
    ///   - availableBranches: Available git branches
    ///   - defaultAgentPubkey: Optional default agent pubkey (e.g., most recent message author)
    ///   - onSend: Callback when message is sent
    public init(
        viewModel: ChatInputViewModel,
        dataStore: DataStore,
        ndk: NDK,
        projectReference: String,
        availableModels: [String] = [],
        availableTools: [String] = [],
        availableBranches: [String] = [],
        defaultAgentPubkey: String? = nil,
        onSend: @escaping (String, String?, [String]) -> Void
    ) {
        self.ndk = ndk
        self.dataStore = dataStore
        self.projectReference = projectReference
        self.availableModels = availableModels
        self.availableTools = availableTools
        self.availableBranches = availableBranches
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
            replyContextView
            nudgesPillsView
            mentionAutocompleteView
            mainInputArea
        }
        .onChange(of: viewModel.inputText) { _, newValue in
            handleTextChange(newValue)
        }
        .onChange(of: agentSelectorVM.selectedAgentPubkey) { _, newPubkey in
            handleAgentSelection(newPubkey)
        }
        .sheet(isPresented: $showNudgeSelector) {
            NudgeSelectorSheet(
                selectedNudges: $viewModel.selectedNudges,
                availableNudges: dataStore.nudges
            )
        }
        .sheet(isPresented: $showBranchSelector) {
            BranchSelectorSheet(
                selectedBranch: $viewModel.selectedBranch,
                availableBranches: availableBranches
            )
        }
        .sheet(isPresented: $showAgentConfig) {
            if let agent = agentSelectorVM.selectedAgentPubkey.flatMap({ pubkey in
                agentSelectorVM.agents.first(where: { $0.pubkey == pubkey })
            }) {
                AgentConfigSheet(
                    isPresented: $showAgentConfig,
                    agent: agent,
                    availableModels: availableModels,
                    availableTools: availableTools,
                    projectReference: projectReference,
                    ndk: ndk
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
    private let availableModels: [String]
    private let availableTools: [String]
    private let availableBranches: [String]
    private let onSend: (String, String?, [String]) -> Void

    // MARK: - View Components

    @ViewBuilder private var replyContextView: some View {
        if let replyTo = viewModel.replyToMessage {
            ReplyContextBanner(message: replyTo) {
                viewModel.clearReplyTo()
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
    }

    @ViewBuilder private var nudgesPillsView: some View {
        if !viewModel.selectedNudges.isEmpty {
            SelectedNudgesPills(
                selectedNudges: viewModel.selectedNudges,
                availableNudges: dataStore.nudges
            ) { viewModel.toggleNudge($0) }
                .padding(.vertical, 8)
        }
    }

    @ViewBuilder private var mentionAutocompleteView: some View {
        if mentionVM.isVisible {
            MentionAutocompleteView(viewModel: mentionVM, ndk: ndk) { replacement, pubkey in
                handleMentionSelection(replacement: replacement, pubkey: pubkey)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
    }

    private var mainInputArea: some View {
        VStack(spacing: 12) {
            controlsRow

            if viewModel.isExpanded {
                expandedInputBar
            } else {
                compactInputBar
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.platformBackground)
    }

    // MARK: - Controls Row

    private var controlsRow: some View {
        HStack(spacing: 8) {
            nudgeButton
            AgentSelectorButton(viewModel: agentSelectorVM)
            branchButton
            Spacer()
            expandButton
        }
    }

    private var nudgeButton: some View {
        Button {
            showNudgeSelector = true
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "square.slash")
                    .font(.system(size: 14))
                if !viewModel.selectedNudges.isEmpty {
                    Text("\(viewModel.selectedNudges.count)")
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
            showBranchSelector = true
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "arrow.branch")
                    .font(.system(size: 14))
                if let branch = viewModel.selectedBranch {
                    Text(branch)
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }
            .foregroundStyle(viewModel.selectedBranch != nil ? .green : .primary)
        }
        .buttonStyle(.plain)
    }

    private var expandButton: some View {
        Button {
            viewModel.setExpanded(!viewModel.isExpanded)
        } label: {
            Image(systemName: viewModel.isExpanded ? "chevron.down" : "chevron.up")
                .font(.system(size: 14))
                .foregroundStyle(.primary)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Input Bars

    private var compactInputBar: some View {
        HStack(alignment: .bottom, spacing: 8) {
            ZStack(alignment: .leading) {
                if viewModel.inputText.isEmpty {
                    Text("Message...")
                        .font(.system(size: 16))
                        .foregroundStyle(.tertiary)
                        .padding(.leading, 4)
                }
                TextEditor(text: $viewModel.inputText)
                    .font(.system(size: 16))
                    .scrollContentBackground(.hidden)
                    .background(.clear)
                    .focused($isInputFocused)
                    .frame(minHeight: 36, maxHeight: 120)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 4)

            sendButton
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
            TextEditor(text: $viewModel.inputText)
                .font(.system(.body, design: .monospaced))
                .scrollContentBackground(.hidden)
                .background(Color.platformSecondaryBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .frame(minHeight: 200, maxHeight: 400)
                .focused($isInputFocused)
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
                sendButton
            }
        }
    }

    private var sendButton: some View {
        Button {
            sendMessage()
        } label: {
            Image(systemName: "arrow.up")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(viewModel.canSend ? Color.accentColor : Color.gray.opacity(0.4))
                )
        }
        .buttonStyle(.plain)
        .disabled(!viewModel.canSend)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.15), value: viewModel.canSend)
        #if os(macOS)
            .keyboardShortcut(.return, modifiers: .command)
        #endif
        #if os(iOS)
        .hoverEffect(.lift)
        #endif
        .accessibilityLabel("Send message")
        .accessibilityHint(viewModel.canSend ? "Double tap to send" : "Enter a message first")
    }

    private func sendMessage() {
        let text = viewModel.inputText
        let agentPubkey = agentSelectorVM.selectedAgentPubkey
        let mentions = viewModel.mentionedPubkeys
        onSend(text, agentPubkey, mentions)
        viewModel.clearInput()
    }

    private func handleTextChange(_ newText: String) {
        mentionVM.updateInput(text: newText, cursorPosition: newText.count)

        // Auto-expand when text > 300 chars
        if newText.count > 300, !viewModel.isExpanded {
            viewModel.setExpanded(true)
        }
    }

    private func handleAgentSelection(_ pubkey: String?) {
        if let pubkey {
            viewModel.selectAgent(pubkey)
        }
    }

    private func handleMentionSelection(replacement: String, pubkey: String) {
        viewModel.insertMention(replacement: replacement, pubkey: pubkey)
        mentionVM.hide()
    }
}
