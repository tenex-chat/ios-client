//
// ChatView.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import SwiftUI
import TENEXCore

// MARK: - ChatView

/// Main chat view displaying messages in a thread
public struct ChatView: View {
    // MARK: Lifecycle

    /// Initialize the chat view
    /// - Parameters:
    ///   - threadId: The thread identifier
    ///   - ndk: The NDK instance for fetching and publishing messages
    ///   - currentUserPubkey: The current user's pubkey
    public init(threadID: String, ndk: any NDKSubscribing & NDKPublishing, currentUserPubkey: String) {
        _viewModel = State(initialValue: ChatViewModel(ndk: ndk, threadID: threadID, userPubkey: currentUserPubkey))
        self.currentUserPubkey = currentUserPubkey
    }

    // MARK: Public

    public var body: some View {
        Group {
            if viewModel.isLoading, viewModel.messages.isEmpty {
                loadingView
            } else if viewModel.messages.isEmpty {
                emptyView
            } else {
                messageList
            }
        }
        .task {
            await viewModel.loadMessages()
        }
        .task {
            await viewModel.subscribeToStreamingDeltas()
        }
        .task {
            await viewModel.subscribeToTypingIndicators()
        }
        .refreshable {
            await viewModel.refresh()
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

    // MARK: Private

    @State private var viewModel: ChatViewModel

    private let currentUserPubkey: String

    private var typingText: String {
        let count = viewModel.typingUsers.count
        if count == 1 {
            return "Someone is typing..."
        } else {
            return "\(count) people are typing..."
        }
    }

    private var messageList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(viewModel.messages) { message in
                    MessageRow(message: message, currentUserPubkey: currentUserPubkey)
                        .padding(.horizontal, 16)
                }

                // Typing indicators at bottom
                if !viewModel.typingUsers.isEmpty {
                    typingIndicator
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                }
            }
            .padding(.vertical, 16)
        }
    }

    private var typingIndicator: some View {
        HStack(spacing: 8) {
            Image(systemName: "ellipsis.bubble.fill")
                .font(.system(size: 20))
                .foregroundStyle(.blue)
                .symbolEffect(.pulse)

            Text(typingText)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
        }
    }

    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
            Text("Loading messages...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
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
}
