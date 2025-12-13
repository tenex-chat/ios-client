//
// ChatInputView.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import SwiftUI

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
public struct ChatInputView: View {
    // MARK: Lifecycle

    /// Initialize the chat input view
    /// - Parameter viewModel: The input view model
    public init(viewModel: ChatInputViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    // MARK: Public

    public var body: some View {
        VStack(spacing: 12) {
            // Input toolbar
            inputToolbar

            // Text input
            textInput

            // Agent and branch selectors
            HStack(spacing: 8) {
                agentSelector
                branchSelector
                Spacer()
                sendButton
            }
        }
        .padding(12)
        .background(Color.platformBackground)
    }

    // MARK: Private

    @State private var viewModel: ChatInputViewModel

    private var inputToolbar: some View {
        HStack(spacing: 16) {
            // Attachment button
            Button {
                // Placeholder action
            } label: {
                Image(systemName: "paperclip")
                    .font(.system(size: 20))
                    .foregroundStyle(.secondary)
            }

            // Mic button
            Button {
                // Placeholder action - will navigate to voice mode
            } label: {
                Image(systemName: "mic.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.secondary)
            }

            Spacer()
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

    private var agentSelector: some View {
        Button {
            // Show agent selector
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 16))
                Text(viewModel.selectedAgent ?? "Select Agent")
                    .font(.system(size: 12))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.blue.opacity(0.1))
            .foregroundStyle(.blue)
            .cornerRadius(14)
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
            // Send message action
            viewModel.clearInput()
        } label: {
            Image(systemName: "arrow.up.circle.fill")
                .font(.system(size: 32))
                .foregroundStyle(viewModel.canSend ? .blue : .gray)
        }
        .disabled(!viewModel.canSend)
    }
}
