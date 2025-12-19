//
// ChatView.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

// swiftformat:disable organizeDeclarations
// swiftlint:disable file_length

import AVFoundation
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
                self.contentView(ndk: ndk)
            } else {
                Text("NDK not available")
            }
        }
        #if os(iOS)
        .toolbar(.hidden, for: .tabBar)
        #endif
    }

    // MARK: Private

    @Environment(\.ndk) private var ndk
    @Environment(\.audioService) private var audioService
    @Environment(\.aiConfigStorage) private var aiConfigStorage
    @Environment(DataStore.self) private var dataStore
    @State private var viewModel: ChatViewModel?
    @State private var focusStack: [Message] = [] // Stack of focused messages for navigation
    @State private var inputViewModel: ChatInputViewModel?
    @State private var isShowingSettings = false
    @State private var isShowingCallView = false
    @State private var callViewErrorMessage: String?

    // Scroll management state
    @State private var shouldAutoScroll = true
    @State private var lastMessageCount = 0

    private let threadEvent: NDKEvent?
    private let projectReference: String
    private let currentUserPubkey: String

    /// Online agents from DataStore
    private var onlineAgents: [ProjectAgent] {
        self.dataStore.getProjectStatus(projectCoordinate: self.projectReference)?.agents ?? []
    }

    /// Whether this is a new thread (no existing threadEvent)
    private var isNewThread: Bool {
        self.threadEvent == nil
    }

    /// The currently focused message (nil = showing root level)
    private var focusedMessage: Message? {
        self.focusStack.last
    }

    /// The ID we're currently focused on (root thread ID if not focused on anything)
    private var focusedEventID: String? {
        self.focusedMessage?.id ?? self.threadEvent?.id
    }

    /// Whether we're showing a focused (non-root) view
    private var isShowingFocusedView: Bool {
        !self.focusStack.isEmpty
    }

    /// Extract project d-tag from projectReference (format: "31933:pubkey:d-tag")
    private var projectDTag: String {
        self.projectReference.components(separatedBy: ":").last ?? self.projectReference
    }

    /// Extract owner pubkey from projectReference (format: "31933:pubkey:d-tag")
    private var projectOwnerPubkey: String {
        let components = self.projectReference.components(separatedBy: ":")
        guard components.count >= 3 else {
            return self.projectReference
        }
        return components[1]
    }

    private var backButton: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: self.navigateBack) {
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
                .font(.largeTitle)
                .imageScale(.large)
                .foregroundStyle(.blue)

            Text(isNewThread ? "Start a New Thread" : "No Messages Yet")
                .font(.title2)
                .fontWeight(.semibold)

            Text(isNewThread ? "Select an agent and send your first message" : "Start a conversation in this thread")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func contentView(ndk: NDK) -> some View {
        let vm = self.viewModel ?? ChatViewModel(
            ndk: ndk,
            threadEvent: self.threadEvent,
            projectReference: self.projectReference,
            userPubkey: self.currentUserPubkey
        )

        self.mainContent(viewModel: vm)
            .task {
                if self.viewModel == nil {
                    self.viewModel = vm
                }
                if self.inputViewModel == nil {
                    // Use thread ID if available, otherwise use project reference for new threads
                    let conversationID = vm.threadID ?? self.projectReference
                    self.inputViewModel = ChatInputViewModel(
                        conversationID: conversationID,
                        isNewThread: vm.isNewThread
                    )
                }
            }
            .onChange(of: vm.threadEvent) { _, newThreadEvent in
                // Update input view model when thread is created
                if newThreadEvent != nil, let inputVM = inputViewModel {
                    inputVM.isNewThread = false
                }
            }
    }

    @ViewBuilder
    // swiftlint:disable:next function_body_length
    private func mainContent(viewModel: ChatViewModel) -> some View {
        @Bindable var bindableViewModel = viewModel
        let displayedMessages = self.messagesForCurrentFocus(viewModel: viewModel)

        VStack(spacing: 0) {
            if self.isShowingFocusedView {
                self.backButton
            }
            self.messagesArea(viewModel: viewModel, messages: displayedMessages)
        }
        .safeAreaInset(edge: .bottom) {
            self.inputBar(viewModel: viewModel)
        }
        .navigationTitle(self.navigationTitle(viewModel: viewModel))
        .navigationBarBackButtonHidden(self.isShowingFocusedView)
        .toolbar {
            ToolbarItem(placement: .automatic) {
                HStack(spacing: 12) {
                    Button {
                        self.isShowingCallView = true
                    } label: {
                        Image(systemName: "phone.fill")
                            .foregroundStyle(.blue)
                    }
                    .accessibilityLabel("Start voice call")

                    Button {
                        self.isShowingSettings = true
                    } label: {
                        Image(systemName: "gear")
                    }
                }
            }
        }
        .sheet(isPresented: self.$isShowingSettings) {
            NavigationView {
                ConversationSettingsView(settings: $bindableViewModel.conversationSettings)
                    .toolbar {
                        ToolbarItem(placement: .automatic) {
                            Button("Done") {
                                self.isShowingSettings = false
                            }
                        }
                    }
            }
        }
        #if os(iOS)
        .fullScreenCover(isPresented: self.$isShowingCallView) {
            if let ndk, let callVM = self.createCallViewModel() {
                ZStack {
                    Color.black.ignoresSafeArea()

                    CallView(
                        viewModel: callVM,
                        ndk: ndk,
                        projectReference: self.projectReference,
                        dataStore: self.dataStore,
                        onDismiss: {
                            self.isShowingCallView = false
                        },
                        projectColor: .blue,
                        availableAgents: self.onlineAgents
                    )
                    .frame(maxWidth: 390, maxHeight: 844) // iPhone dimensions
                }
            } else {
                Text("Unable to start call")
                    .onAppear {
                        self.isShowingCallView = false
                    }
            }
        }
        #else
        .sheet(isPresented: self.$isShowingCallView) {
                    if let ndk, let callVM = self.createCallViewModel() {
                        CallView(
                            viewModel: callVM,
                            ndk: ndk,
                            projectReference: self.projectReference,
                            dataStore: self.dataStore,
                            onDismiss: {
                                self.isShowingCallView = false
                            },
                            projectColor: .blue,
                            availableAgents: self.onlineAgents
                        )
                    } else {
                        Text("Unable to start call")
                            .onAppear {
                                self.isShowingCallView = false
                            }
                    }
                } // swiftlint:disable:this closure_end_indentation
        #endif
                .task {
                    // Only subscribe to metadata for existing threads
                    if !viewModel.isNewThread {
                        await viewModel.subscribeToThreadMetadata()
                    }
                }
                .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                    Button("OK") {}
                } message: {
                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                    }
                }
                .alert("Voice Call Error", isPresented: .constant(self.callViewErrorMessage != nil)) {
                    Button("OK") {
                        self.callViewErrorMessage = nil
                    }
                } message: {
                    if let errorMessage = callViewErrorMessage {
                        Text(errorMessage)
                    }
                }
    }

    @ViewBuilder
    private func messagesArea(viewModel: ChatViewModel, messages: [Message]) -> some View {
        if messages.isEmpty {
            self.emptyView(isNewThread: viewModel.isNewThread)
        } else {
            self.messageList(viewModel: viewModel, messages: messages)
        }
    }

    @ViewBuilder
    private func inputBar(viewModel: ChatViewModel) -> some View {
        if let ndk, let inputVM = inputViewModel {
            VStack(spacing: 0) {
                // Show active agents with stop controls when agents are working
                if let threadID = viewModel.threadID {
                    ActiveAgentsView(
                        eventId: threadID,
                        projectReference: self.projectReference,
                        onlineAgents: self.onlineAgents
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }

                ChatInputView(
                    viewModel: inputVM,
                    dataStore: self.dataStore,
                    ndk: ndk,
                    projectReference: self.projectReference,
                    defaultAgentPubkey: self.mostRecentAgentPubkey(from: viewModel.displayMessages)
                ) { text, agentPubkey, mentions in
                    Task {
                        await viewModel.sendMessage(
                            text: text,
                            targetAgentPubkey: agentPubkey,
                            mentionedPubkeys: mentions,
                            replyTo: inputVM.replyToMessage,
                            selectedNudges: inputVM.selectedNudges,
                            selectedBranch: inputVM.selectedBranch
                        )
                    }
                }
            }
        }
    }

    /// Find the most recent agent that wrote a message in the conversation
    /// - Parameter messages: The display messages from the conversation
    /// - Returns: The pubkey of the most recent agent, or nil if no agent messages exist
    private func mostRecentAgentPubkey(from messages: [Message]) -> String? {
        // Iterate from the end (most recent) to find the first agent message
        // Agent messages are those where the pubkey is in the onlineAgents list
        let agentPubkeys = Set(onlineAgents.map(\.pubkey))
        return messages.last { message in
            agentPubkeys.contains(message.pubkey)
        }?.pubkey
    }

    private func messageList(viewModel: ChatViewModel, messages: [Message]) -> some View {
        ScrollViewReader { proxy in
            self.messageScrollView(viewModel: viewModel, messages: messages)
                .coordinateSpace(name: "scroll")
                .onPreferenceChange(ScrollOffsetPreferenceKey.self) { offset in
                    self.handleScrollOffsetChange(offset)
                }
                .onAppear {
                    self.handleScrollViewAppear(proxy: proxy, messageCount: messages.count)
                }
                .onChange(of: messages.count) { _, newCount in
                    self.handleMessageCountChange(proxy: proxy, newCount: newCount)
                }
                .onChange(of: viewModel.conversationState.streamingSessions.count) { _, _ in
                    self.handleStreamingSessionsChange(proxy: proxy)
                }
        }
    }

    private func messageScrollView(viewModel: ChatViewModel, messages: [Message]) -> some View {
        GeometryReader { geometry in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    self.messageRows(viewModel: viewModel, messages: messages)
                    self.typingIndicatorView(viewModel: viewModel)
                    self.bottomAnchor
                }
                .padding(.vertical, 16)
            }
            .environment(\.viewportHeight, geometry.size.height)
        }
    }

    /// Filter messages based on conversation settings
    private func filterMessages(_ messages: [Message], settings: ConversationSettings) -> [Message] {
        messages.filter { message in
            if !settings.showReasoning, message.isReasoning {
                return false
            }
            if !settings.showToolCalls, message.isToolCall {
                return false
            }
            return true
        }
    }

    @ViewBuilder
    private func messageRows(viewModel: ChatViewModel, messages: [Message]) -> some View {
        let filteredMessages = self.filterMessages(messages, settings: viewModel.conversationSettings)
        let displayItems = DisplayModelBuilder.createDisplayModel(from: filteredMessages)

        ForEach(Array(displayItems.enumerated()), id: \.element.id) { index, item in
            let isLastItem = index == displayItems.count - 1

            switch item {
            case let .visible(visibleItem):
                self.visibleMessageView(
                    viewModel: viewModel,
                    visibleItem: visibleItem,
                    isLastMessage: isLastItem
                )

            case let .toolGroup(groupItem):
                ToolGroupView(
                    group: groupItem,
                    isConsecutive: groupItem.isConsecutive,
                    hasNextConsecutive: groupItem.hasNextConsecutive
                )

            case .metadata:
                // Metadata items (phase changes) - currently not rendered
                EmptyView()
            }
        }
    }

    @ViewBuilder
    private func visibleMessageView(
        viewModel: ChatViewModel,
        visibleItem: VisibleItem,
        isLastMessage: Bool
    ) -> some View {
        self.messageRowView(
            viewModel: viewModel,
            visibleItem: visibleItem,
            isLastMessage: isLastMessage
        )
    }

    private func messageRowView(
        viewModel: ChatViewModel,
        visibleItem: VisibleItem,
        isLastMessage: Bool
    ) -> some View {
        VStack(spacing: 0) {
            NavigationLink(value: AppRoute.agentProfile(pubkey: visibleItem.message.pubkey)) {
                MessageRow(
                    message: visibleItem.message,
                    currentUserPubkey: self.currentUserPubkey,
                    isConsecutive: visibleItem.isConsecutive,
                    hasNextConsecutive: visibleItem.hasNextConsecutive,
                    onReplyTap: { self.replyToMessage(visibleItem.message) },
                    onAgentTap: visibleItem.message.pubkey != self.currentUserPubkey ? {} : nil,
                    onQuote: { self.quoteMessage(visibleItem.message, viewModel: viewModel) },
                    onPlayTTS: TTSCache.shared
                        .hasCached(messageID: visibleItem.message.id) ?
                        { self.playTTSForMessage(visibleItem.message.id) } : nil,
                    showDebugInfo: false
                )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .id(visibleItem.message.id)

            // Track visibility of last message to detect scroll position
            if isLastMessage {
                self.scrollPositionTracker
            }
        }
    }

    @ViewBuilder
    private func typingIndicatorView(viewModel: ChatViewModel) -> some View {
        if !viewModel.typingUsers.isEmpty {
            self.typingIndicator(viewModel: viewModel)
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
        self.shouldAutoScroll = offset < 100
    }

    private func handleScrollViewAppear(proxy: ScrollViewProxy, messageCount: Int) {
        withAnimation {
            proxy.scrollTo("bottom", anchor: .bottom)
        }
        self.lastMessageCount = messageCount
    }

    private func handleMessageCountChange(proxy: ScrollViewProxy, newCount: Int) {
        // Only auto-scroll if user is near bottom and new messages were added
        if self.shouldAutoScroll, newCount > self.lastMessageCount {
            withAnimation {
                proxy.scrollTo("bottom", anchor: .bottom)
            }
        }
        self.lastMessageCount = newCount
    }

    private func handleStreamingSessionsChange(proxy: ScrollViewProxy) {
        // Scroll when streaming starts if at bottom
        if self.shouldAutoScroll {
            withAnimation {
                proxy.scrollTo("bottom", anchor: .bottom)
            }
        }
    }

    private func typingIndicator(viewModel: ChatViewModel) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "ellipsis.bubble.fill")
                .font(.title3)
                .foregroundStyle(.blue)
                .symbolEffect(.pulse)

            Text(self.typingText(viewModel: viewModel))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    /// Get messages to display based on current focus
    /// - Shows focused message + direct replies to focused message
    private func messagesForCurrentFocus(viewModel: ChatViewModel) -> [Message] {
        if !self.isShowingFocusedView {
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
            .filter { $0.replyTo == self.focusedEventID }
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
        self.focusStack.append(message)
    }

    /// Handle reply action - if message has replies, navigate to thread; otherwise set as reply target
    private func replyToMessage(_ message: Message) {
        if message.replyCount > 0 {
            // Message has replies, navigate to the thread view
            self.focusOnMessage(message)
        } else {
            // Message has no replies, set it as the reply target
            self.inputViewModel?.setReplyTo(message)
        }
    }

    /// Navigate back to parent
    private func navigateBack() {
        guard !self.focusStack.isEmpty else {
            return
        }
        self.focusStack.removeLast()
    }

    private func navigationTitle(viewModel: ChatViewModel) -> String {
        if self.isShowingFocusedView {
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

    private func quoteMessage(_ message: Message, viewModel _: ChatViewModel) {
        let quotedText = message.content
            .split(separator: "\n")
            .map { "> \($0)" }
            .joined(separator: "\n")
        self.inputViewModel?.inputText = quotedText + "\n\n"
    }

    /// Play cached TTS audio for a message
    private func playTTSForMessage(_ messageID: String) {
        guard let audioService,
              let audioData = TTSCache.shared.audioFor(messageID: messageID)
        else {
            return
        }

        Task {
            try? await audioService.play(audioData: audioData)
        }
    }

    /// Create a CallViewModel for the voice call
    /// - Returns: A configured CallViewModel, or nil if unable to create (no agent, no audio service, etc.)
    private func createCallViewModel() -> CallViewModel? {
        // Validate required services
        guard let audioService, let ndk else {
            self.callViewErrorMessage = "Audio service or NDK not available"
            return nil
        }

        guard let chatViewModel = viewModel else {
            self.callViewErrorMessage = "Chat not initialized"
            return nil
        }

        // Get selected agent
        guard let agent = selectAgentForCall(chatViewModel: chatViewModel) else {
            self.callViewErrorMessage = "No agent available. Please select an agent or wait for project to start."
            return nil
        }

        // Get voice ID and settings
        let voiceID = AgentVoiceConfigStorage().config(for: agent.pubkey)?.voiceID
        let keychain = KeychainStorage(service: "com.tenex.ai")
        let storage = UserDefaultsAIConfigStorage(keychain: keychain)
        let settings = (try? storage.load())?.voiceCallSettings ?? VoiceCallSettings()
        let vadController = self.createVADControllerIfNeeded(settings: settings)

        // Create CallViewModel
        return CallViewModel(
            audioService: audioService,
            ndk: ndk,
            projectID: self.projectReference,
            agent: agent,
            userPubkey: self.currentUserPubkey,
            voiceID: voiceID,
            rootEvent: chatViewModel.threadEvent, // Pass existing thread
            branchTag: nil,
            enableVOD: true,
            autoTTS: true,
            vadController: vadController,
            vadMode: settings.vadMode
        )
    }

    /// Select agent for voice call (most recent responder or first online)
    private func selectAgentForCall(chatViewModel: ChatViewModel) -> ProjectAgent? {
        if let agentPubkey = mostRecentAgentPubkey(from: chatViewModel.displayMessages) {
            return self.onlineAgents.first { $0.pubkey == agentPubkey }
        }
        return self.onlineAgents.first
    }

    /// Create VAD controller if VAD mode requires it
    private func createVADControllerIfNeeded(settings: VoiceCallSettings) -> VADController? {
        guard settings.vadMode == .auto || settings.vadMode == .autoWithHold else {
            return nil
        }
        let audioEngine = AVAudioEngine()
        return VADController(
            audioEngine: audioEngine,
            vadMethod: settings.vadMethod,
            sensitivity: settings.vadSensitivity
        )
    }
}

// MARK: - Array Safe Subscript

private extension Array {
    /// Safe array subscript that returns nil instead of crashing
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
