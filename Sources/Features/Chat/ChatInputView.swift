//
// ChatInputView.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import NDKSwiftCore
import NDKSwiftUI
import SwiftUI
import TENEXCore
import TENEXShared

#if os(iOS)
    import UIKit
#else
    import AppKit
#endif

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
    ///   - onlineAgents: List of online agents in the project
    ///   - availableHashtags: List of available hashtags for routing
    ///   - lastAgentPubkey: The last agent that spoke (for auto-updating selection)
    ///   - onSend: Callback when message is sent (text, agentPubkey, mentions, hashtag, attachmentURLs)
    public init(
        viewModel: ChatInputViewModel,
        dataStore: DataStore,
        ndk: NDK,
        projectReference: String,
        defaultAgentPubkey: String? = nil,
        onlineAgents: [ProjectAgent] = [],
        availableHashtags: [String] = [],
        lastAgentPubkey: String? = nil,
        onSend: @escaping (String, String?, [String], String?, [String]) -> Void
    ) {
        self.ndk = ndk
        self.dataStore = dataStore
        self.projectReference = projectReference
        self.onlineAgents = onlineAgents
        self.availableHashtags = availableHashtags
        self.lastAgentPubkey = lastAgentPubkey
        self.onSend = onSend
        _viewModel = State(initialValue: viewModel)
        _agentSelectorVM = State(initialValue: AgentSelectorViewModel(
            dataStore: dataStore,
            projectReference: projectReference,
            defaultAgentPubkey: defaultAgentPubkey,
            availableHashtags: availableHashtags
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
            self.attachmentPreviewView
            self.nudgesPillsView
            self.mentionAutocompleteView
            self.mainInputArea
        }
        #if os(macOS)
        .overlay {
            if self.isDropTargeted {
                self.dropTargetOverlay
            }
        }
        .dropDestination(for: Data.self) { items, _ in
            self.handleDroppedData(items)
        } isTargeted: { isTargeted in
            withAnimation(.easeInOut(duration: 0.2)) {
                self.isDropTargeted = isTargeted
            }
        }
        #endif
        .onChange(of: self.viewModel.inputText) { _, newValue in
            self.handleTextChange(newValue)
        }
        .onChange(of: self.agentSelectorVM.selectedAgentPubkey) { _, newPubkey in
            self.handleAgentSelection(newPubkey)
        }
        .onChange(of: self.agentSelectorVM.selectedHashtag) { _, newHashtag in
            self.viewModel.selectedHashtag = newHashtag
        }
        .onChange(of: self.lastAgentPubkey) { _, newAgentPubkey in
            // Auto-update the selected agent when the last speaking agent changes
            self.agentSelectorVM.updateDefaultAgent(newAgentPubkey)
        }
        .sheet(isPresented: self.$agentSelectorVM.isPresented) {
            AgentSelectorView(viewModel: self.agentSelectorVM)
        }
        #if os(iOS)
        .sheet(isPresented: self.$showComposeSheet) {
            ComposeSheetView(
                viewModel: self.viewModel,
                agentSelectorVM: self.agentSelectorVM,
                dataStore: self.dataStore,
                ndk: self.ndk,
                projectReference: self.projectReference,
                onlineAgents: self.onlineAgents,
                onSend: self.onSend
            ) {
                self.showComposeSheet = false
            }
        }
        #endif
    }

    // MARK: Private

    @State private var viewModel: ChatInputViewModel
    @State private var agentSelectorVM: AgentSelectorViewModel
    @State private var mentionVM: MentionAutocompleteViewModel
    @State private var showComposeSheet = false
    @FocusState private var isInputFocused: Bool

    #if os(macOS)
    @State private var isDropTargeted = false
    #endif

    /// Reduce Motion accessibility setting
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let ndk: NDK
    private let dataStore: DataStore
    private let projectReference: String
    private let onlineAgents: [ProjectAgent]
    private let availableHashtags: [String]
    private let lastAgentPubkey: String?
    private let onSend: (String, String?, [String], String?, [String]) -> Void

    /// Dynamic placeholder text showing selected agent or hashtag
    private var placeholderText: String {
        if let hashtag = agentSelectorVM.selectedHashtag {
            return "Post to #\(hashtag)"
        }
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

    @ViewBuilder private var attachmentPreviewView: some View {
        if self.viewModel.hasAttachments {
            AttachmentPreviewRow(attachments: self.viewModel.pendingAttachments) { attachment in
                self.viewModel.removeAttachment(attachment)
            }
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
        self.textInputField
    }

    private var textInputField: some View {
        #if os(iOS)
        // iOS: Tappable collapsed bar that opens compose sheet
        collapsedInputBar
        #else
        // macOS: Inline text editor
        inlineTextEditor
        #endif
    }

    #if os(iOS)
    private var collapsedInputBar: some View {
        Button {
            showComposeSheet = true
        } label: {
            HStack(spacing: 12) {
                // Agent avatar if selected
                if let pubkey = agentSelectorVM.selectedAgentPubkey {
                    NDKUIProfilePicture(ndk: ndk, pubkey: pubkey, size: 28)
                }

                // Placeholder or preview text
                Text(viewModel.inputText.isEmpty ? placeholderText : viewModel.inputText)
                    .font(.body)
                    .foregroundStyle(viewModel.inputText.isEmpty ? .secondary : .primary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Attachment count badge
                if viewModel.hasAttachments {
                    Text("\(viewModel.pendingAttachments.count)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.accentColor))
                }

                // Send button (enabled state)
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundStyle(viewModel.canSend ? Color.accentColor : Color.gray.opacity(0.4))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
        .modifier(GlassTextFieldModifier())
    }
    #endif

    private var inlineTextEditor: some View {
        HStack(alignment: .bottom, spacing: 0) {
            ZStack(alignment: .topLeading) {
                if self.viewModel.inputText.isEmpty {
                    Text(self.placeholderText)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 10)
                }
                TextEditor(text: self.$viewModel.inputText)
                    .font(.body)
                    .scrollContentBackground(.hidden)
                    .background(.clear)
                    .focused(self.$isInputFocused)
                    .frame(minHeight: 36, maxHeight: 200)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 2)

            self.sendButton
                .padding(.trailing, 2)
                .padding(.bottom, 2)
        }
        .padding(.leading, 12)
        .modifier(GlassTextFieldModifier())
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
        // Use selected hashtag from dropdown, or extract from content (e.g., "hello #world")
        let hashtag = self.agentSelectorVM.selectedHashtag ?? self.viewModel.firstExtractedHashtag
        let attachmentURLs = self.viewModel.uploadedAttachmentURLs
        self.onSend(text, agentPubkey, mentions, hashtag, attachmentURLs)
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

    #if os(macOS)
    // MARK: - Drag and Drop (macOS only)

    private var dropTargetOverlay: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .strokeBorder(Color.accentColor, lineWidth: 3)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.accentColor.opacity(0.1))
            )
            .overlay {
                VStack(spacing: 8) {
                    Image(systemName: "photo.badge.plus")
                        .font(.system(size: 32, weight: .medium))
                        .foregroundStyle(Color.accentColor)
                    Text("Drop images here")
                        .font(.headline)
                        .foregroundStyle(Color.accentColor)
                }
            }
    }

    /// Handle dropped image data
    private func handleDroppedData(_ items: [Data]) -> Bool {
        var addedAny = false

        for data in items {
            if let (imageData, mimeType, thumbnail) = self.processImageData(data) {
                self.viewModel.addAttachment(
                    imageData: imageData,
                    mimeType: mimeType,
                    thumbnail: thumbnail
                )
                addedAny = true
            }
        }

        // Trigger upload for new attachments
        if addedAny {
            Task {
                for attachment in self.viewModel.pendingAttachments where attachment.uploadState == .pending {
                    await attachment.upload(ndk: self.ndk)
                }
            }
        }

        return addedAny
    }
    #endif

    /// Process raw data into image data, mime type, and thumbnail
    private func processImageData(_ data: Data) -> (Data, String, Image)? {
        #if os(iOS)
        guard let uiImage = UIImage(data: data) else {
            return nil
        }

        // Determine mime type from data
        let mimeType = self.detectImageMimeType(data)

        // Convert to JPEG for consistent upload format
        guard let jpegData = uiImage.jpegData(compressionQuality: 0.8) else {
            return nil
        }

        let thumbnail = Image(uiImage: uiImage)
        return (jpegData, mimeType, thumbnail)
        #else
        guard let nsImage = NSImage(data: data) else {
            return nil
        }

        let mimeType = self.detectImageMimeType(data)

        // Convert to JPEG for consistent upload format
        guard let tiffRep = nsImage.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffRep),
              let jpegData = bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: 0.8])
        else {
            return nil
        }

        let thumbnail = Image(nsImage: nsImage)
        return (jpegData, mimeType, thumbnail)
        #endif
    }

    /// Detect image mime type from data header bytes
    private func detectImageMimeType(_ data: Data) -> String {
        guard data.count >= 8 else {
            return "image/jpeg"
        }

        let bytes = [UInt8](data.prefix(8))

        // PNG: 89 50 4E 47 0D 0A 1A 0A
        if bytes[0] == 0x89, bytes[1] == 0x50, bytes[2] == 0x4E, bytes[3] == 0x47 {
            return "image/png"
        }

        // JPEG: FF D8 FF
        if bytes[0] == 0xFF, bytes[1] == 0xD8, bytes[2] == 0xFF {
            return "image/jpeg"
        }

        // GIF: 47 49 46 38
        if bytes[0] == 0x47, bytes[1] == 0x49, bytes[2] == 0x46, bytes[3] == 0x38 {
            return "image/gif"
        }

        // WebP: 52 49 46 46 ... 57 45 42 50
        if bytes[0] == 0x52, bytes[1] == 0x49, bytes[2] == 0x46, bytes[3] == 0x46 {
            return "image/webp"
        }

        // Default to JPEG
        return "image/jpeg"
    }
}
