//
// ChatInputView.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import NDKSwiftCore
import SwiftUI
import TENEXCore

#if os(iOS)
    import PhotosUI
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
            content.glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        } else {
            content
                .background(Color.platformSecondaryBackground)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
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
    ///   - eventId: Optional event ID to track active agents for
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
        eventId: String? = nil,
        onlineAgents: [ProjectAgent] = [],
        availableHashtags: [String] = [],
        lastAgentPubkey: String? = nil,
        onSend: @escaping (String, String?, [String], String?, [String]) -> Void
    ) {
        self.ndk = ndk
        self.dataStore = dataStore
        self.projectReference = projectReference
        self.eventId = eventId
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
        .sheet(isPresented: self.$agentSelectorVM.isPresented) {
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
    @FocusState private var isInputFocused: Bool

    #if os(macOS)
    @State private var isDropTargeted = false
    #endif

    // Pulsing animation state for active agents indicator
    @State private var pulseScale: CGFloat = 1.0
    @State private var pulseOpacity: Double = 0.5

    /// Dynamic Type scaling for send button
    @ScaledMetric(relativeTo: .body) private var sendButtonSize: CGFloat = 32
    @ScaledMetric(relativeTo: .body) private var sendIconSize: CGFloat = 14

    /// Reduce Motion accessibility setting
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let ndk: NDK
    private let dataStore: DataStore
    private let projectReference: String
    private let eventId: String?
    private let onlineAgents: [ProjectAgent]
    private let availableHashtags: [String]
    private let lastAgentPubkey: String?
    private let onSend: (String, String?, [String], String?, [String]) -> Void

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

    /// Get active agent pubkeys for this event from DataStore
    private var activeAgentPubkeys: Set<String> {
        guard let eventId else {
            return []
        }
        return self.dataStore.activeOperations[eventId] ?? []
    }

    /// Filter online agents to only those currently active
    private var activeAgents: [ProjectAgent] {
        self.onlineAgents.filter { self.activeAgentPubkeys.contains($0.pubkey) }
    }

    /// Whether any agents are currently working
    private var hasActiveAgents: Bool {
        !self.activeAgents.isEmpty
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
        HStack(alignment: .bottom, spacing: 6) {
            self.atButton
            #if os(iOS)
            self.imageButton
            #endif
            self.textInputField
            self.plusMenuButton
        }
    }

    private var textInputField: some View {
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

    private var atButton: some View {
        Button {
            self.agentSelectorVM.presentSelector()
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
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.5)
                .onEnded { _ in
                    if self.agentSelectorVM.selectedAgentPubkey != nil {
                        self.showAgentConfig = true
                    }
                }
        )
        .padding(.bottom, 2)
    }

    #if os(iOS)
    private var imageButton: some View {
        PhotosPicker(
            selection: self.$viewModel.selectedPhotoItems,
            maxSelectionCount: 4,
            matching: .images,
            photoLibrary: .shared()
        ) {
            Image(systemName: "photo")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(
                    self.viewModel.hasAttachments
                        ? Color.primary
                        : .secondary
                )
                .frame(width: 36, height: 36)
                .modifier(GlassCircleButtonModifier())
        }
        .buttonStyle(.plain)
        .padding(.bottom, 2)
        .onChange(of: self.viewModel.pendingAttachments) { _, attachments in
            // Auto-upload attachments when added
            Task {
                for attachment in attachments where attachment.uploadState == .pending {
                    await attachment.upload(ndk: self.ndk)
                }
            }
        }
    }
    #endif

    private var plusMenuButton: some View {
        Menu {
            // Show stop options first if agents are active
            if self.hasActiveAgents {
                self.stopAgentsSection
                Divider()
            }

            self.nudgesMenuItem
            self.branchMenuItem
            Divider()
            self.agentSettingsMenuItem
        } label: {
            ZStack {
                // Icon changes based on active agents
                Image(systemName: self.hasActiveAgents ? "xmark" : "plus")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(self.hasActiveAgents ? .red : .secondary)
                    .frame(width: 36, height: 36)
                    .modifier(GlassCircleButtonModifier())

                // Pulsing indicator when agents are active
                if self.hasActiveAgents {
                    Circle()
                        .fill(Color.red.opacity(0.3))
                        .frame(width: 36, height: 36)
                        .scaleEffect(self.pulseScale)
                        .opacity(self.pulseOpacity)
                        .onAppear {
                            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                                self.pulseScale = 1.3
                                self.pulseOpacity = 0.1
                            }
                        }
                        .onDisappear {
                            // Reset state for next time
                            self.pulseScale = 1.0
                            self.pulseOpacity = 0.5
                        }
                }
            }
        }
        .padding(.bottom, 2)
        .accessibilityLabel(self.hasActiveAgents ? "Stop active agents or more options" : "More options")
    }

    @ViewBuilder
    private var stopAgentsSection: some View {
        if self.activeAgents.count > 1 {
            Button(role: .destructive) {
                Task { await self.stopAllAgents() }
            } label: {
                Label("Cancel All", systemImage: "stop.circle.fill")
            }
            Divider()
        }

        ForEach(self.activeAgents, id: \.pubkey) { agent in
            Button(role: .destructive) {
                Task { await self.stopAgent(agent.pubkey) }
            } label: {
                Label("Cancel \(agent.name)", systemImage: "stop.circle")
            }
        }
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

    // MARK: - Active Agents Management

    /// Stop a specific agent
    private func stopAgent(_ pubkey: String) async {
        guard let eventId else {
            return
        }
        // Stop commands are best-effort - silently ignore errors
        try? await MessagePublisher().publishStopCommand(
            ndk: self.ndk,
            projectRef: self.projectReference,
            eventId: eventId,
            agentPubkey: pubkey
        )
    }

    /// Stop all active agents
    private func stopAllAgents() async {
        guard let eventId else {
            return
        }
        // Stop commands are best-effort - silently ignore errors
        try? await MessagePublisher().publishStopCommand(
            ndk: self.ndk,
            projectRef: self.projectReference,
            eventId: eventId,
            agentPubkey: nil // nil means stop all
        )
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
