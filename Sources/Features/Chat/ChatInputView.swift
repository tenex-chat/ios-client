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

// MARK: - Glass Effect Modifiers

private struct GlassTextFieldModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            content.glassEffect(.regular, in: .capsule)
        } else {
            content
                .background(Color.platformSecondaryBackground)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.5)
                )
        }
    }
}

private struct GlassCircleButtonModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            content.glassEffect(.regular.interactive(), in: .circle)
        } else {
            content
        }
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
        .sheet(isPresented: self.$showAgentSelector) {
            AgentSelectorView(viewModel: self.agentSelectorVM)
        }
    }

    // MARK: Private

    @State private var viewModel: ChatInputViewModel
    @State private var agentSelectorVM: AgentSelectorViewModel
    @State private var mentionVM: MentionAutocompleteViewModel
    @State private var showNudgeSelector = false
    @State private var showBranchSelector = false
    @State private var showAgentConfig = false
    @State private var showAgentSelector = false
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
        self.dataStore.getProjectStatus(projectCoordinate: self.projectReference)?
            .models ?? []
    }

    /// Available tools from project status
    private var availableTools: [String] {
        self.dataStore.getProjectStatus(projectCoordinate: self.projectReference)?
            .tools ?? []
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

    /// Dynamic placeholder text showing selected agent
    private var placeholderText: String {
        if let pubkey = agentSelectorVM.selectedAgentPubkey,
           let agent = agentSelectorVM.agents.first(where: { $0.pubkey == pubkey }) {
            return "Message @\(agent.name)"
        }
        return "Message @agent"
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
        self.compactInputBar
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
    }

    // MARK: - Input Bar

    private var compactInputBar: some View {
        HStack(alignment: .bottom, spacing: 6) {
            self.atButton
            self.textInputField
            self.plusMenuButton
        }
    }

    private var textInputField: some View {
        HStack(alignment: .bottom, spacing: 0) {
            ZStack(alignment: .leading) {
                if self.viewModel.inputText.isEmpty {
                    Text(self.placeholderText)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .padding(.leading, 6)
                }
                TextEditor(text: self.$viewModel.inputText)
                    .font(.body)
                    .scrollContentBackground(.hidden)
                    .background(.clear)
                    .focused(self.$isInputFocused)
                    .frame(minHeight: 36, maxHeight: 200)
                    .fixedSize(horizontal: false, vertical: true)
            }

            self.sendButton
                .padding(.trailing, 2)
                .padding(.bottom, 2)
        }
        .padding(.leading, 12)
        .modifier(GlassTextFieldModifier())
    }

    private var atButton: some View {
        Button {
            self.showAgentSelector = true
        } label: {
            Text("@")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(
                    self.agentSelectorVM.selectedAgentPubkey != nil
                        ? Color.primary
                        : .secondary
                )
                .frame(width: 36, height: 36)
                .modifier(GlassCircleButtonModifier())
        }
        .buttonStyle(.plain)
        .padding(.bottom, 2)
    }

    private var plusMenuButton: some View {
        Menu {
            self.nudgesMenuItem
            self.branchMenuItem
            Divider()
            self.agentSettingsMenuItem
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 36, height: 36)
                .modifier(GlassCircleButtonModifier())
        }
        .padding(.bottom, 2)
    }

    private var nudgesMenuItem: some View {
        Button {
            self.showNudgeSelector = true
        } label: {
            Label(self.nudgesMenuLabel, systemImage: "square.slash")
        }
    }

    private var nudgesMenuLabel: String {
        self.viewModel.selectedNudges.isEmpty ? "Nudges" : "Nudges (\(self.viewModel.selectedNudges.count))"
    }

    private var branchMenuItem: some View {
        Button {
            self.showBranchSelector = true
        } label: {
            Label(self.branchMenuLabel, systemImage: "arrow.branch")
        }
    }

    private var branchMenuLabel: String {
        displayBranch.map { "Branch (\($0))" } ?? "Branch"
    }

    private var agentSettingsMenuItem: some View {
        Button {
            self.showAgentConfig = true
        } label: {
            Label("Agent Settings", systemImage: "gearshape")
        }
        .disabled(self.agentSelectorVM.selectedAgentPubkey == nil)
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
