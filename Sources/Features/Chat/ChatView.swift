//
// ChatView.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import NDKSwiftCore
import SwiftUI
import TENEXCore

// MARK: - ScrollOffsetPreferenceKey

/// Preference key for tracking scroll offset to detect user scroll position
private struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - ChatView

/// Main chat view displaying messages in a thread
public struct ChatView: View { // swiftlint:disable:this type_body_length

    // MARK: Lifecycle

    /// Initialize the chat view
    /// - Parameters:
    ///   - threadEvent: The thread event (kind:11) to display messages for, or nil for new thread mode
    ///   - projectReference: The project reference in format "31933:pubkey:d-tag"
    ///   - currentUserPubkey: The current user's pubkey
    public init(
        threadEvent: NDKEvent?,
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
    @Environment(DataStore.self) private var dataStore
    @State private var viewModel: ChatViewModel?
    @State private var focusStack: [Message] = [] // Stack of focused messages for navigation
    @State private var inputViewModel = ChatInputViewModel()
    @State private var onlineAgents: [ProjectAgent] = []
    @State private var availableModels: [String] = []
    @State private var availableTools: [String] = []
    @State private var availableBranches: [String] = []

    // Scroll management state
    @State private var shouldAutoScroll = true
    @State private var lastMessageCount = 0

    private let threadEvent: NDKEvent?
    private let projectReference: String
    private let currentUserPubkey: String

    /// Whether this is a new thread (no existing threadEvent)
    private var isNewThread: Bool {
        threadEvent == nil
    }

    /// The currently focused message (nil = showing root level)
    private var focusedMessage: Message? {
        focusStack.last
    }

    /// The ID we're currently focused on (root thread ID if not focused on anything)
    private var focusedEventID: String? {
        focusedMessage?.id ?? threadEvent?.id
    }

    /// Whether we're showing a focused (non-root) view
    private var isShowingFocusedView: Bool {
        !focusStack.isEmpty
    }

    /// Extract project d-tag from projectReference (format: "31933:pubkey:d-tag")
    private var projectDTag: String {
        projectReference.components(separatedBy: ":").last ?? projectReference
    }

    /// Extract owner pubkey from projectReference (format: "31933:pubkey:d-tag")
    private var projectOwnerPubkey: String {
        let components = projectReference.components(separatedBy: ":")
        guard components.count >= 3 else {
            return projectReference
        }
        return components[1]
    }

    private var backButton: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: navigateBack) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .foregroundColor(.accentColor)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                Spacer()
            }
            #if os(iOS)
            .background(Color(uiColor: .systemBackground))
            #else
            .background(Color(nsColor: .windowBackgroundColor))
            #endif
            Divider()
        }
    }

    @ViewBuilder
    private func emptyView(isNewThread: Bool) -> some View {
        VStack(spacing: 20) {
            Image(systemName: isNewThread ? "plus.bubble.fill" : "bubble.left.fill")
                .font(.system(size: 60))
                .foregroundStyle(.blue)

            Text(isNewThread ? "Start a New Thread" : "No Messages Yet")
                .font(.title)
                .fontWeight(.semibold)

            Text(isNewThread ? "Select an agent and send your first message" : "Start a conversation in this thread")
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
            .onChange(of: vm.threadEvent) { _, newThreadEvent in
                // Update input view model when thread is created
                if newThreadEvent != nil {
                    inputViewModel.setRequiresAgent(false)
                }
            }
    }

    @ViewBuilder
    private func mainContent(viewModel: ChatViewModel) -> some View {
        let displayedMessages = messagesForCurrentFocus(viewModel: viewModel)

        VStack(spacing: 0) {
            if isShowingFocusedView {
                backButton
            }
            messagesArea(viewModel: viewModel, messages: displayedMessages)
            inputBar(viewModel: viewModel)
        }
        .navigationTitle(navigationTitle(viewModel: viewModel))
        .navigationBarBackButtonHidden(isShowingFocusedView)
        .task {
            // Only subscribe to metadata for existing threads
            if !viewModel.isNewThread {
                await viewModel.subscribeToThreadMetadata()
            }
        }
        .onAppear {
            // Configure input for new thread mode (requires agent selection)
            inputViewModel.setRequiresAgent(viewModel.isNewThread)
        }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") {}
        } message: {
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
            }
        }
    }

    @ViewBuilder
    private func messagesArea(viewModel: ChatViewModel, messages: [Message]) -> some View {
        if messages.isEmpty {
            emptyView(isNewThread: viewModel.isNewThread)
        } else {
            messageList(viewModel: viewModel, messages: messages)
        }
    }

    @ViewBuilder
    private func inputBar(viewModel: ChatViewModel) -> some View {
        if let ndk {
            Divider()
            ChatInputView(
                viewModel: inputViewModel,
                dataStore: dataStore,
                ndk: ndk,
                projectReference: projectReference,
                availableModels: availableModels,
                availableTools: availableTools,
                availableBranches: availableBranches
            ) { text, agentPubkey, mentions in
                Task {
                    await viewModel.sendMessage(
                        text: text,
                        targetAgentPubkey: agentPubkey,
                        mentionedPubkeys: mentions,
                        replyTo: inputViewModel.replyToMessage,
                        selectedNudges: inputViewModel.selectedNudges,
                        selectedBranch: inputViewModel.selectedBranch
                    )
                }
            }
        }
    }

    private func messageList(viewModel: ChatViewModel, messages: [Message]) -> some View {
        ScrollViewReader { proxy in
            messageScrollView(viewModel: viewModel, messages: messages)
                .coordinateSpace(name: "scroll")
                .onPreferenceChange(ScrollOffsetPreferenceKey.self) { offset in
                    handleScrollOffsetChange(offset)
                }
                .onAppear {
                    handleScrollViewAppear(proxy: proxy, messageCount: messages.count)
                }
                .onChange(of: messages.count) { _, newCount in
                    handleMessageCountChange(proxy: proxy, newCount: newCount)
                }
                .onChange(of: viewModel.conversationState.streamingSessions.count) { _, _ in
                    handleStreamingSessionsChange(proxy: proxy)
                }
        }
    }

    private func messageScrollView(viewModel: ChatViewModel, messages: [Message]) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                messageRows(viewModel: viewModel, messages: messages)
                typingIndicatorView(viewModel: viewModel)
                bottomAnchor
            }
            .padding(.vertical, 16)
        }
    }

    @ViewBuilder
    private func messageRows(viewModel: ChatViewModel, messages: [Message]) -> some View {
        ForEach(Array(messages.enumerated()), id: \.element.id) { index, message in
            messageRowView(viewModel: viewModel, message: message, index: index, messages: messages)
        }
    }

    private func messageRowView(
        viewModel: ChatViewModel,
        message: Message,
        index: Int,
        messages: [Message]
    ) -> some View {
        let isConsecutive = isConsecutiveMessage(at: index, in: messages)
        let hasNextConsecutive = hasNextConsecutiveMessage(at: index, in: messages)

        return VStack(spacing: 0) {
            NavigationLink(value: AppRoute.agentProfile(pubkey: message.pubkey)) {
                MessageRow(
                    message: message,
                    currentUserPubkey: currentUserPubkey,
                    isConsecutive: isConsecutive,
                    hasNextConsecutive: hasNextConsecutive,
                    onReplyTap: message.replyCount > 0 ? { focusOnMessage(message) } : nil,
                    onAgentTap: message.pubkey != currentUserPubkey ? {} : nil,
                    onQuote: { quoteMessage(message, viewModel: viewModel) },
                    onReplySwipe: {
                        inputViewModel.setReplyTo(message)
                    },
                    showDebugInfo: false
                )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .id(message.id)

            // Track visibility of last message to detect scroll position
            if index == messages.count - 1 {
                scrollPositionTracker
            }
        }
    }

    @ViewBuilder
    private func typingIndicatorView(viewModel: ChatViewModel) -> some View {
        if !viewModel.typingUsers.isEmpty {
            typingIndicator(viewModel: viewModel)
                .padding(.horizontal, 16)
                .padding(.top, 16)
        }
    }

    private var bottomAnchor: some View {
        Color.clear
            .frame(height: 1)
            .id("bottom")
    }

    private var scrollPositionTracker: some View {
        Color.clear
            .frame(height: 1)
            .background(
                GeometryReader { geo in
                    Color.clear.preference(
                        key: ScrollOffsetPreferenceKey.self,
                        value: geo.frame(in: .named("scroll")).minY
                    )
                }
            )
    }

    private func handleScrollOffsetChange(_ offset: CGFloat) {
        // User is at bottom if offset is small (within 100 points)
        shouldAutoScroll = offset < 100
    }

    private func handleScrollViewAppear(proxy: ScrollViewProxy, messageCount: Int) {
        withAnimation {
            proxy.scrollTo("bottom", anchor: .bottom)
        }
        lastMessageCount = messageCount
    }

    private func handleMessageCountChange(proxy: ScrollViewProxy, newCount: Int) {
        // Only auto-scroll if user is near bottom and new messages were added
        if shouldAutoScroll && newCount > lastMessageCount {
            withAnimation {
                proxy.scrollTo("bottom", anchor: .bottom)
            }
        }
        lastMessageCount = newCount
    }

    private func handleStreamingSessionsChange(proxy: ScrollViewProxy) {
        // Scroll when streaming starts if at bottom
        if shouldAutoScroll {
            withAnimation {
                proxy.scrollTo("bottom", anchor: .bottom)
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

    /// Get messages to display based on current focus
    /// - Shows focused message + direct replies to focused message
    private func messagesForCurrentFocus(viewModel: ChatViewModel) -> [Message] {
        if !isShowingFocusedView {
            // At root level, use the normal display messages
            return viewModel.displayMessages
        }

        // For focused view, show:
        // 1. The focused message itself
        // 2. Direct replies to the focused message
        var result: [Message] = []

        // Add focused message
        if let focused = focusedMessage {
            result.append(focused)
        }

        // Add direct replies to focused message
        let directReplies = viewModel.allMessages.values
            .filter { $0.replyTo == focusedEventID }
            .sorted { $0.createdAt < $1.createdAt }

        // Compute reply counts for each direct reply
        for reply in directReplies {
            let nestedReplies = viewModel.allMessages.values.filter { $0.replyTo == reply.id }
            if nestedReplies.isEmpty {
                result.append(reply)
            } else {
                let uniquePubkeys = Array(Set(nestedReplies.map(\.pubkey)).prefix(3))
                result.append(reply.with(replyCount: nestedReplies.count, replyAuthorPubkeys: uniquePubkeys))
            }
        }

        return result
    }

    /// Navigate into a message's replies
    private func focusOnMessage(_ message: Message) {
        focusStack.append(message)
    }

    /// Navigate back to parent
    private func navigateBack() {
        guard !focusStack.isEmpty else {
            return
        }
        focusStack.removeLast()
    }

    private func navigationTitle(viewModel: ChatViewModel) -> String {
        if isShowingFocusedView {
            return "Replies"
        }
        if viewModel.isNewThread {
            return "New Thread"
        }
        return viewModel.threadTitle ?? "Thread"
    }

    private func typingText(viewModel: ChatViewModel) -> String {
        let count = viewModel.typingUsers.count
        if count == 1 {
            return "Someone is typing..."
        } else {
            return "\(count) people are typing..."
        }
    }

    /// Subscribe to ProjectStatus events to get online agents, models, tools, and branches
    private func subscribeToProjectStatus() async {
        guard let ndk else {
            return
        }

        let filter = ProjectStatus.filter(for: projectOwnerPubkey)
        let subscription = ndk.subscribe(filter: filter)

        for await event in subscription.events {
            if let status = ProjectStatus.from(event: event),
               status.projectCoordinate == projectReference {
                await MainActor.run {
                    onlineAgents = status.agents

                    // Extract unique models and tools from all agents
                    availableModels = Array(Set(status.agents.compactMap(\.model))).sorted()
                    availableTools = Array(Set(status.agents.flatMap(\.tools))).sorted()

                    // Extract branches from ProjectStatus
                    availableBranches = status.branches.sorted()
                }
            }
        }
    }

    private func isConsecutiveMessage(at index: Int, in messages: [Message]) -> Bool {
        guard index > 0, index < messages.count else {
            return false
        }
        let currentMessage = messages[index]
        let previousMessage = messages[index - 1]
        return currentMessage.pubkey == previousMessage.pubkey &&
            currentMessage.pTaggedPubkeys.isEmpty
    }

    private func hasNextConsecutiveMessage(at index: Int, in messages: [Message]) -> Bool {
        guard index < messages.count - 1 else {
            return false
        }
        let currentMessage = messages[index]
        let nextMessage = messages[index + 1]
        return currentMessage.pubkey == nextMessage.pubkey &&
            nextMessage.pTaggedPubkeys.isEmpty
    }

    private func quoteMessage(_ message: Message, viewModel _: ChatViewModel) {
        let quotedText = message.content
            .split(separator: "\n")
            .map { "> \($0)" }
            .joined(separator: "\n")
        inputViewModel.inputText = quotedText + "\n\n"
    }
}
