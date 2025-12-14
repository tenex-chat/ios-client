//
// ChatView.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import NDKSwiftCore
import SwiftUI
import TENEXCore

// MARK: - ChatView

/// Main chat view displaying messages in a thread
public struct ChatView: View {
    // MARK: Lifecycle

    /// Initialize the chat view
    /// - Parameters:
    ///   - threadEvent: The thread event (kind:11) to display messages for
    ///   - projectReference: The project reference in format "31933:pubkey:d-tag"
    ///   - currentUserPubkey: The current user's pubkey
    public init(
        threadEvent: NDKEvent,
        projectReference: String,
        currentUserPubkey: String
    ) {
        self.threadEvent = threadEvent
        self.projectReference = projectReference
        self.currentUserPubkey = currentUserPubkey
    }

    // MARK: Public

    public var body: some View {
        Group {
            if let ndk {
                contentView(ndk: ndk)
            } else {
                Text("NDK not available")
            }
        }
    }

    // MARK: Private

    @Environment(\.ndk) private var ndk
    @State private var viewModel: ChatViewModel?
    @State private var focusedMessage: Message?
    @State private var inputViewModel = ChatInputViewModel()
    @State private var onlineAgents: [ProjectAgent] = []

    private let threadEvent: NDKEvent
    private let projectReference: String
    private let currentUserPubkey: String

    /// Extract project d-tag from projectReference (format: "31933:pubkey:d-tag")
    private var projectDTag: String {
        projectReference.components(separatedBy: ":").last ?? projectReference
    }

    private var emptyView: some View {
        VStack(spacing: 20) {
            Image(systemName: "bubble.left.fill")
                .font(.system(size: 60))
                .foregroundStyle(.blue)

            Text("No Messages Yet")
                .font(.title)
                .fontWeight(.semibold)

            Text("Start a conversation in this thread")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func contentView(ndk: NDK) -> some View {
        let vm = viewModel ?? ChatViewModel(
            ndk: ndk,
            threadEvent: threadEvent,
            projectReference: projectReference,
            userPubkey: currentUserPubkey
        )

        mainContent(viewModel: vm)
            .task {
                if viewModel == nil {
                    viewModel = vm
                }
            }
    }

    @ViewBuilder
    private func mainContent(viewModel: ChatViewModel) -> some View {
        VStack(spacing: 0) {
            // Messages area (scrollable)
            Group {
                if viewModel.displayMessages.isEmpty {
                    emptyView
                } else {
                    messageList(viewModel: viewModel)
                }
            }

            // Input bar at bottom
            if let ndk {
                Divider()
                ChatInputView(
                    viewModel: inputViewModel,
                    agents: onlineAgents,
                    ndk: ndk
                ) { text, agentPubkey, mentions in
                    Task {
                        await viewModel.sendMessage(
                            text: text,
                            targetAgentPubkey: agentPubkey,
                            mentionedPubkeys: mentions,
                            replyTo: nil
                        )
                    }
                }
            }
        }
        .navigationTitle(viewModel.threadTitle ?? "Thread")
        .task {
            await viewModel.subscribeToThreadMetadata()
        }
        .task {
            await subscribeToProjectStatus()
        }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") {
                // Error message will be cleared on next load
            }
        } message: {
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
            }
        }
    }

    private func messageList(viewModel: ChatViewModel) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(viewModel.displayMessages) { message in
                    NavigationLink(value: AppRoute.agentProfile(pubkey: message.pubkey)) {
                        MessageRow(
                            message: message,
                            currentUserPubkey: currentUserPubkey,
                            onReplyTap: message.replyCount > 0 ? { focusedMessage = message } : nil,
                            onRetry: makeRetryAction(for: message, viewModel: viewModel),
                            onAgentTap: message.pubkey != currentUserPubkey ? {} : nil
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)
                }

                // Typing indicators at bottom
                if !viewModel.typingUsers.isEmpty {
                    typingIndicator(viewModel: viewModel)
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                }
            }
            .padding(.vertical, 16)
        }
        .sheet(item: $focusedMessage) { message in
            ThreadFocusView(
                focusedMessage: message,
                parentMessage: findParentMessage(for: message, in: viewModel),
                replies: findReplies(for: message, in: viewModel),
                currentUserPubkey: currentUserPubkey
            ) {
                focusedMessage = nil
            }
        }
    }

    private func typingIndicator(viewModel: ChatViewModel) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "ellipsis.bubble.fill")
                .font(.system(size: 20))
                .foregroundStyle(.blue)
                .symbolEffect(.pulse)

            Text(typingText(viewModel: viewModel))
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
        }
    }

    private func findParentMessage(for message: Message, in viewModel: ChatViewModel) -> Message? {
        guard let parentID = message.replyTo else {
            return nil
        }
        return viewModel.displayMessages.first { $0.id == parentID }
    }

    private func findReplies(for message: Message, in viewModel: ChatViewModel) -> [Message] {
        viewModel.displayMessages.filter { $0.replyTo == message.id }
    }

    private func typingText(viewModel: ChatViewModel) -> String {
        let count = viewModel.typingUsers.count
        if count == 1 {
            return "Someone is typing..."
        } else {
            return "\(count) people are typing..."
        }
    }

    private func makeRetryAction(for message: Message, viewModel: ChatViewModel) -> (() -> Void)? {
        guard message.status?.isFailed == true else {
            return nil
        }
        return {
            Task {
                await viewModel.retrySendMessage(message)
            }
        }
    }

    /// Subscribe to ProjectStatus events to get online agents
    private func subscribeToProjectStatus() async {
        guard let ndk else {
            return
        }

        let filter = ProjectStatus.filter(for: projectDTag)
        let subscription = ndk.subscribe(filter: filter)

        for await event in subscription.events {
            if let status = ProjectStatus.from(event: event) {
                await MainActor.run {
                    onlineAgents = status.agents
                }
            }
        }
    }
}
