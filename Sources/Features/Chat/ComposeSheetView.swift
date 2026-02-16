//
// ComposeSheetView.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import NDKSwiftCore
import NDKSwiftUI
import PhotosUI
import SwiftUI
import TENEXCore
import TENEXShared

// MARK: - ComposeSheetView

/// Full-screen compose sheet for writing messages with agent selection and attachments
public struct ComposeSheetView: View {
    // MARK: Lifecycle

    public init(
        viewModel: ChatInputViewModel,
        agentSelectorVM: AgentSelectorViewModel,
        dataStore: DataStore,
        ndk: NDK,
        projectReference: String,
        onlineAgents: [ProjectAgent],
        onSend: @escaping (String, String?, [String], String?, [String]) -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.ndk = ndk
        self.dataStore = dataStore
        self.projectReference = projectReference
        self.onlineAgents = onlineAgents
        self.onSend = onSend
        self.onDismiss = onDismiss
        _viewModel = State(initialValue: viewModel)
        _agentSelectorVM = State(initialValue: agentSelectorVM)
    }

    // MARK: Public

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // To: field with agent chip
                toField

                Divider()

                // Main text editor
                textEditorArea

                // Attachment previews
                if viewModel.hasAttachments {
                    attachmentGrid
                }

                Divider()

                // Bottom toolbar
                bottomToolbar
            }
            .navigationTitle("New Message")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onDismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Send") {
                        sendMessage()
                    }
                    .fontWeight(.semibold)
                    .disabled(!viewModel.canSend)
                }
            }
        }
        .sheet(isPresented: $showAgentSelector) {
            AgentSelectorView(viewModel: agentSelectorVM)
        }
        .sheet(isPresented: $showNudgeSelector) {
            NudgeSelectorSheet(
                selectedNudges: $viewModel.selectedNudges,
                availableNudges: dataStore.nudges
            )
        }
        .sheet(isPresented: $showSkillSelector) {
            SkillsSelectorSheet(
                selectedSkills: $viewModel.selectedSkills,
                availableSkills: dataStore.skills
            )
        }
        .onChange(of: agentSelectorVM.selectedAgentPubkey) { _, newPubkey in
            if let newPubkey {
                viewModel.selectAgent(newPubkey)
            }
        }
    }

    // MARK: Private

    @State private var viewModel: ChatInputViewModel
    @State private var agentSelectorVM: AgentSelectorViewModel
    @State private var showAgentSelector = false
    @State private var showNudgeSelector = false
    @State private var showSkillSelector = false
    @FocusState private var isTextFocused: Bool

    private let ndk: NDK
    private let dataStore: DataStore
    private let projectReference: String
    private let onlineAgents: [ProjectAgent]
    private let onSend: (String, String?, [String], String?, [String]) -> Void
    private let onDismiss: () -> Void

    // MARK: - To Field

    private var toField: some View {
        HStack(spacing: 12) {
            Text("To:")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            agentChip

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(uiColor: .secondarySystemBackground))
    }

    @ViewBuilder
    private var agentChip: some View {
        Button {
            showAgentSelector = true
        } label: {
            HStack(spacing: 8) {
                if let pubkey = agentSelectorVM.selectedAgentPubkey,
                   let agent = agentSelectorVM.agents.first(where: { $0.pubkey == pubkey }) {
                    NDKUIProfilePicture(ndk: ndk, pubkey: pubkey, size: 24)
                    Text("@\(agent.name)")
                        .font(.subheadline.weight(.medium))

                    // Online indicator
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                } else {
                    Image(systemName: "at")
                        .font(.subheadline.weight(.medium))
                    Text("Select Agent")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Image(systemName: "chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(Color(uiColor: .tertiarySystemBackground))
            )
            .overlay(
                Capsule()
                    .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Text Editor

    private var textEditorArea: some View {
        VStack(alignment: .leading, spacing: 0) {
            TextEditor(text: $viewModel.inputText)
                .font(.body)
                .scrollContentBackground(.hidden)
                .focused($isTextFocused)
                .frame(minHeight: 200)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

            // Character count
            HStack {
                Spacer()
                Text("\(viewModel.inputText.count)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
        .onAppear {
            isTextFocused = true
        }
    }

    // MARK: - Attachment Grid

    private var attachmentGrid: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(viewModel.pendingAttachments) { attachment in
                    attachmentThumbnail(attachment)
                }

                // Add more button
                addAttachmentButton
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color(uiColor: .secondarySystemBackground))
    }

    private func attachmentThumbnail(_ attachment: PendingAttachment) -> some View {
        ZStack(alignment: .topTrailing) {
            attachment.thumbnail
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 12))

            // Upload state overlay
            uploadStateOverlay(for: attachment)

            // Remove button
            Button {
                viewModel.removeAttachment(attachment)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.white)
                    .shadow(radius: 2)
            }
            .offset(x: 6, y: -6)
        }
    }

    @ViewBuilder
    private func uploadStateOverlay(for attachment: PendingAttachment) -> some View {
        switch attachment.uploadState {
        case .pending, .uploading:
            RoundedRectangle(cornerRadius: 12)
                .fill(.black.opacity(0.5))
                .frame(width: 80, height: 80)
                .overlay {
                    ProgressView()
                        .tint(.white)
                }
        case .completed:
            EmptyView()
        case .failed:
            RoundedRectangle(cornerRadius: 12)
                .fill(.red.opacity(0.5))
                .frame(width: 80, height: 80)
                .overlay {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.white)
                }
        }
    }

    private var addAttachmentButton: some View {
        PhotosPicker(
            selection: $viewModel.selectedPhotoItems,
            maxSelectionCount: 4,
            matching: .images
        ) {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [6]))
                .foregroundStyle(.secondary)
                .frame(width: 80, height: 80)
                .overlay {
                    Image(systemName: "plus")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
        }
        .onChange(of: viewModel.pendingAttachments) { _, attachments in
            Task {
                for attachment in attachments where attachment.uploadState == .pending {
                    await attachment.upload(ndk: ndk)
                }
            }
        }
    }

    // MARK: - Bottom Toolbar

    private var bottomToolbar: some View {
        HStack(spacing: 20) {
            imagePickerButton
            moreOptionsMenu
            Spacer()
            nudgesBadge
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(uiColor: .secondarySystemBackground))
    }

    private var imagePickerButton: some View {
        PhotosPicker(
            selection: $viewModel.selectedPhotoItems,
            maxSelectionCount: 4,
            matching: .images
        ) {
            Image(systemName: "photo")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
    }

    private var moreOptionsMenu: some View {
        Menu {
            Button {
                // Branch selector would go here
            } label: {
                Label("Branch", systemImage: "arrow.branch")
            }

            Button {
                showNudgeSelector = true
            } label: {
                Label("Nudges", systemImage: "square.slash")
            }

            Button {
                showSkillSelector = true
            } label: {
                Label("Skills", systemImage: "bolt.fill")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var nudgesBadge: some View {
        HStack(spacing: 8) {
            if !viewModel.selectedNudges.isEmpty {
                Text("\(viewModel.selectedNudges.count) nudges")
                    .font(.caption)
                    .foregroundStyle(.blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.blue.opacity(0.1)))
            }
            if !viewModel.selectedSkills.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "bolt.fill")
                        .font(.caption2)
                    Text("\(viewModel.selectedSkills.count)")
                }
                .font(.caption)
                .foregroundStyle(.orange)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.orange.opacity(0.1)))
            }
        }
    }

    // MARK: - Actions

    private func sendMessage() {
        let text = viewModel.inputText
        let agentPubkey = agentSelectorVM.selectedAgentPubkey
        let mentions = viewModel.mentionedPubkeys
        let hashtag = agentSelectorVM.selectedHashtag ?? viewModel.firstExtractedHashtag
        let attachmentURLs = viewModel.uploadedAttachmentURLs

        onSend(text, agentPubkey, mentions, hashtag, attachmentURLs)
        viewModel.clearInput()
        onDismiss()
    }
}
