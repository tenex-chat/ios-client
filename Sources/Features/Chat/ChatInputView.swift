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
/// Integrates AgentSelector and MentionAutocomplete for @mentions
public struct ChatInputView: View {
    // MARK: Lifecycle

    /// Initialize the chat input view
    /// - Parameters:
    ///   - viewModel: The input view model
    ///   - agents: Online agents for selection and mentions
    ///   - ndk: The NDK instance for profile pictures
    ///   - onSend: Callback when message is sent (text, targetAgentPubkey, mentionedPubkeys)
    public init(
        viewModel: ChatInputViewModel,
        agents: [ProjectAgent],
        ndk: NDK,
        onSend: @escaping (String, String?, [String]) -> Void
    ) {
        self.ndk = ndk
        self.onSend = onSend
        _viewModel = State(initialValue: viewModel)
        _agentSelectorVM = State(initialValue: AgentSelectorViewModel(agents: agents))
        _mentionVM = State(initialValue: MentionAutocompleteViewModel(agents: agents))
    }

    // MARK: Public

    public var body: some View {
        VStack(spacing: 0) {
            // Mention autocomplete popup (shows above input)
            if mentionVM.isVisible {
                MentionAutocompleteView(viewModel: mentionVM, ndk: ndk) { replacement, pubkey in
                    handleMentionSelection(replacement: replacement, pubkey: pubkey)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }

            // Main input area
            VStack(spacing: 12) {
                // Agent selector row - always show so user knows who they're addressing
                agentRow

                // Unified input bar
                inputBar
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.platformBackground)
        }
        .onChange(of: viewModel.inputText) { _, newValue in
            handleTextChange(newValue)
        }
        .onChange(of: agentSelectorVM.selectedAgentPubkey) { _, newPubkey in
            handleAgentSelection(newPubkey)
        }
    }

    // MARK: Private

    @State private var viewModel: ChatInputViewModel
    @State private var agentSelectorVM: AgentSelectorViewModel
    @State private var mentionVM: MentionAutocompleteViewModel
    @FocusState private var isInputFocused: Bool

    private let ndk: NDK
    private let onSend: (String, String?, [String]) -> Void

    private var agentRow: some View {
        HStack(spacing: 8) {
            AgentSelectorButton(viewModel: agentSelectorVM)
            branchChip
            Spacer()
        }
    }

    @ViewBuilder private var branchChip: some View {
        if let branch = viewModel.selectedBranch {
            HStack(spacing: 4) {
                Image(systemName: "arrow.branch")
                    .font(.system(size: 11, weight: .medium))
                Text(branch)
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(.green)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(.green.opacity(0.12), in: Capsule())
        }
    }

    private var inputBar: some View {
        HStack(alignment: .bottom, spacing: 8) {
            textEditor
            sendButton
        }
        .padding(.leading, 16)
        .padding(.trailing, 6)
        .padding(.vertical, 6)
        .background(Color.platformSecondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(inputBarBorder)
    }

    private var inputBarBorder: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
    }

    private var textEditor: some View {
        ZStack(alignment: .leading) {
            textPlaceholder
            textField
        }
        .padding(.horizontal, 4)
    }

    @ViewBuilder private var textPlaceholder: some View {
        if viewModel.inputText.isEmpty {
            Text("Message...")
                .font(.system(size: 16))
                .foregroundStyle(.tertiary)
                .padding(.leading, 4)
        }
    }

    private var textField: some View {
        TextEditor(text: $viewModel.inputText)
            .font(.system(size: 16))
            .scrollContentBackground(.hidden)
            .background(.clear)
            .focused($isInputFocused)
            .frame(minHeight: 36, maxHeight: 120)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var sendButton: some View {
        Button {
            sendMessage()
        } label: {
            sendButtonIcon
        }
        .buttonStyle(.plain)
        .disabled(!viewModel.canSend)
        .animation(.easeInOut(duration: 0.15), value: viewModel.canSend)
    }

    private var sendButtonIcon: some View {
        Image(systemName: "arrow.up")
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 32, height: 32)
            .background(sendButtonBackground)
    }

    private var sendButtonBackground: some View {
        Circle()
            .fill(viewModel.canSend ? Color.accentColor : Color.gray.opacity(0.4))
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
