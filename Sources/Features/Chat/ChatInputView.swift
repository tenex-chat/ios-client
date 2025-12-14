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
        VStack(spacing: 12) {
            // Input toolbar
            inputToolbar

            // Text input with mention autocomplete overlay
            ZStack(alignment: .topLeading) {
                textInput

                // Mention autocomplete popup
                if mentionVM.isVisible {
                    MentionAutocompleteView(viewModel: mentionVM, ndk: ndk) { replacement, pubkey in
                        handleMentionSelection(replacement: replacement, pubkey: pubkey)
                    }
                    .padding(.top, -140) // Position above the input
                }
            }

            // Agent and branch selectors
            HStack(spacing: 8) {
                AgentSelectorButton(viewModel: agentSelectorVM)
                branchSelector
                Spacer()
                sendButton
            }
        }
        .padding(12)
        .background(Color.platformBackground)
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

    private let ndk: NDK
    private let onSend: (String, String?, [String]) -> Void

    private var inputToolbar: some View {
        HStack(spacing: 16) {
            attachmentButton
            micButton
            Spacer()
        }
    }

    private var attachmentButton: some View {
        Button {
            // Placeholder action
        } label: {
            Image(systemName: "paperclip")
                .font(.system(size: 20))
                .foregroundStyle(.secondary)
        }
    }

    private var micButton: some View {
        Button {
            // Placeholder - voice mode not yet implemented
        } label: {
            Image(systemName: "mic")
                .font(.system(size: 20))
                .foregroundStyle(.secondary)
        }
    }

    private var textInput: some View {
        TextEditor(text: $viewModel.inputText)
            .font(.system(size: 16))
            .frame(minHeight: 40, maxHeight: 120)
            .padding(8)
            .background(Color.platformSecondaryBackground)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.platformSeparator, lineWidth: 1)
            )
            .overlay(alignment: .topLeading) {
                if viewModel.inputText.isEmpty {
                    Text("Message...")
                        .font(.system(size: 16))
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 16)
                        .allowsHitTesting(false)
                }
            }
    }

    private var branchSelector: some View {
        Group {
            if let branch = viewModel.selectedBranch {
                Button {
                    // Show branch selector
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.branch")
                            .font(.system(size: 14))
                        Text(branch)
                            .font(.system(size: 12))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.green.opacity(0.1))
                    .foregroundStyle(.green)
                    .cornerRadius(14)
                }
            }
        }
    }

    private var sendButton: some View {
        Button {
            let text = viewModel.inputText
            let agentPubkey = agentSelectorVM.selectedAgentPubkey
            let mentions = viewModel.mentionedPubkeys
            onSend(text, agentPubkey, mentions)
            viewModel.clearInput()
        } label: {
            Image(systemName: "arrow.up.circle.fill")
                .font(.system(size: 32))
                .foregroundStyle(viewModel.canSend ? .blue : .gray)
        }
        .disabled(!viewModel.canSend)
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
