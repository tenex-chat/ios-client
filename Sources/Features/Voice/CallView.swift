//
// CallView.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import AVFoundation
import NDKSwiftCore
import SwiftUI
import TENEXCore

// MARK: - CallView

// swiftlint:disable type_body_length file_length

/// Enhanced call view with auto-TTS, STT, and VOD recording
/// Displays agent avatar, conversation history, audio controls, and status
public struct CallView: View {
    // MARK: Lifecycle

    /// Initialize call view
    /// - Parameters:
    ///   - viewModel: Call view model
    ///   - ndk: NDK instance for profile pictures
    ///   - projectReference: The project reference coordinate
    ///   - dataStore: Data store for project status
    ///   - onDismiss: Callback when call is dismissed
    ///   - projectColor: Project accent color
    ///   - availableAgents: List of agents to choose from
    public init(
        viewModel: CallViewModel,
        ndk: NDK,
        projectReference: String,
        dataStore: DataStore,
        onDismiss: @escaping () -> Void,
        projectColor: Color = .blue,
        availableAgents: [ProjectAgent] = []
    ) {
        _viewModel = State(initialValue: viewModel)
        self.ndk = ndk
        self.projectColor = projectColor
        self.availableAgents = availableAgents
        self.projectReference = projectReference
        self.dataStore = dataStore
        self.onDismiss = onDismiss
    }

    // MARK: Public

    public var body: some View {
        ZStack {
            self.backgroundGradient
            self.contentView
        }
        .preferredColorScheme(.dark)
        .task {
            // Request microphone permission first
            #if os(iOS)
                let permission = AVAudioApplication.shared.recordPermission
                if permission == .undetermined {
                    _ = await AVAudioApplication.requestRecordPermission()
                }
            #endif

            // Track when call session started
            self.sessionStartTime = Date()

            // Start call when view appears
            if self.viewModel.state == .idle {
                await self.viewModel.startCall()
            }

            // Auto-start recording - user is here to talk
            if self.viewModel.canRecord {
                await self.viewModel.startRecording()
            }
        }
        .onChange(of: self.viewModel.state) { oldState, newState in
            self.handleStateChange(from: oldState, to: newState)
        }
        .onChange(of: self.viewModel.error) { _, error in
            if error != nil {
                self.hapticManager.error()
            }
        }
    }

    // MARK: Private

    @State private var viewModel: CallViewModel
    @State private var hapticManager = HapticManager()
    @State private var showHoldHint = false
    @State private var sessionStartTime: Date?
    @State private var isShowingSettings = false
    @State private var agentSelectorVM: AgentSelectorViewModel?
    @State private var showAgentConfig = false
    @State private var configAgent: ProjectAgent?

    @Environment(\.aiConfigStorage) private var aiConfigStorage

    private let ndk: NDK
    private let projectColor: Color
    private let availableAgents: [ProjectAgent]
    private let projectReference: String
    private let dataStore: DataStore
    private let onDismiss: () -> Void

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

    /// Messages sent/received during this call session only
    private var sessionMessages: [Message] {
        guard let startTime = sessionStartTime else {
            return []
        }
        guard let conversationState = viewModel.conversationState else {
            return []
        }

        // Only show messages created after call started
        return conversationState.displayMessages.filter {
            $0.createdAt >= startTime
        }
    }

    private var agentInitials: String {
        let words = self.viewModel.agent.name.split(separator: " ")
        if words.count >= 2 {
            return String(words[0].prefix(1) + words[1].prefix(1)).uppercased()
        } else if let first = words.first {
            return String(first.prefix(2)).uppercased()
        }
        return "?"
    }

    private var agentColor: Color {
        let hash = self.viewModel.agent.pubkey.hashValue
        return Color(hue: Double(abs(hash) % 360) / 360.0, saturation: 0.6, brightness: 0.7)
    }

    private var micButtonState: MicButtonState {
        // Muted state takes priority in VAD mode
        if self.viewModel.isMuted, self.isVADMode {
            return .muted
        }

        if self.viewModel.isHoldingMic {
            return .held
        }

        switch self.viewModel.state {
        case .idle:
            return self.isVADMode ? .vadListening : .idle
        case .listening:
            return self.isVADMode ? .vadListening : .idle
        case .recording:
            return .recording
        case .processingSTT:
            return .processing
        case .playingResponse:
            return .playing
        default:
            return .idle
        }
    }

    private var isVADMode: Bool {
        self.viewModel.vadMode == .auto || self.viewModel.vadMode == .autoWithHold
    }

    /// Whether to show agent avatar in center (instead of voice visualizer)
    private var shouldShowAgentInCenter: Bool {
        self.viewModel.state == .playingResponse || self.viewModel.isPaused || self.viewModel.agentIsProcessing
    }

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [Color.black, self.projectColor.opacity(0.3), Color.black],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private var contentView: some View {
        VStack(spacing: 0) {
            self.header
                .padding(.horizontal)
                .padding(.top)

            if self.sessionMessages.isEmpty {
                Spacer()
                self.centerVisualization
                Spacer()
            } else {
                Spacer()
                self.latestMessageView
                    .padding(.horizontal)
                Spacer()
            }

            self.controlsSection
                .padding(.horizontal)
                .padding(.bottom, 40)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            self.endCallButton
            Spacer()
            self.agentSelectorArea
        }
    }

    @ViewBuilder private var agentSelectorArea: some View {
        Button {
            guard self.availableAgents.count > 1 else {
                return
            }
            let vm = AgentSelectorViewModel(
                agents: self.availableAgents,
                defaultAgentPubkey: self.viewModel.agent.pubkey
            )
            vm.isPresented = true
            self.agentSelectorVM = vm
        } label: {
            HStack(spacing: 12) {
                self.agentStatusInfo
                self.agentAvatar
                if self.availableAgents.count > 1 {
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
        }
        .buttonStyle(.plain)
        .sheet(item: self.$agentSelectorVM) { vm in
            AgentSelectorView(viewModel: vm) { self.configAgent = $0; self.showAgentConfig = true }
        }
        .sheet(isPresented: self.$showAgentConfig) {
            if let agent = configAgent {
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
        .onChange(of: self.agentSelectorVM?.selectedAgentPubkey) { _, newPubkey in
            guard let newPubkey,
                  let agent = self.availableAgents.first(where: { $0.pubkey == newPubkey })
            else {
                return
            }
            self.viewModel.changeAgent(agent)
        }
    }

    private var endCallButton: some View {
        Button {
            Task {
                await self.viewModel.endCall()
                self.onDismiss()
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "phone.down.fill")
                    .font(.headline)
                Text("End Call")
                    .font(.subheadline.weight(.medium))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.red.opacity(0.8))
            .clipShape(Capsule())
        }
    }

    private var agentStatusInfo: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text(self.viewModel.agent.name)
                .font(.headline)
                .foregroundStyle(.white)

            VoiceStateIndicator(state: self.viewModel.state)
        }
    }

    private var agentAvatar: some View {
        ZStack {
            Circle()
                .fill(self.agentColor)
                .frame(width: 50, height: 50)

            Text(self.agentInitials)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
        }
    }

    // MARK: - Center Visualization

    @ViewBuilder private var centerVisualization: some View {
        if self.shouldShowAgentInCenter {
            CenterAgentAvatar(
                agentName: self.viewModel.agent.name,
                agentColor: self.agentColor,
                agentInitials: self.agentInitials,
                isSpeaking: self.viewModel.state == .playingResponse,
                isProcessing: self.viewModel.agentIsProcessing,
                isPaused: self.viewModel.isPaused,
                onTap: {
                    self.hapticManager.settingsToggle()
                    self.viewModel.togglePause()
                },
                onLongPress: {
                    self.hapticManager.tapHoldReleased()
                    self.viewModel.interruptAgent()
                }
            )
            .transition(.opacity.combined(with: .scale(scale: 0.9)))
        } else {
            VStack(spacing: 24) {
                VoiceVisualizerView(
                    audioLevel: self.viewModel.audioLevel,
                    isActive: self.viewModel.state == .connecting,
                    color: self.projectColor,
                    size: 120
                )

                Text(self.viewModel
                    .state == .connecting ? "Connecting to \(self.viewModel.agent.name)..." : "Ready to start")
                    .font(.title3)
                    .foregroundStyle(.white)
            }
            .transition(.opacity.combined(with: .scale(scale: 0.9)))
        }
    }

    // MARK: - Latest Message View

    @ViewBuilder private var latestMessageView: some View {
        if let message = sessionMessages.last {
            VStack(spacing: 8) {
                if message.isReasoning {
                    Label("Reasoning", systemImage: "brain")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.white.opacity(0.6))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.purple.opacity(0.3))
                        .clipShape(Capsule())
                }
                MessageBubble(
                    message: message,
                    accentColor: self.projectColor,
                    userPubkey: self.viewModel.userPubkey
                ) {
                    Task { await self.viewModel.replayMessage(message.id) }
                }
            }
            .id(message.id)
            .transition(.opacity.combined(with: .scale(scale: 0.98)))
            .animation(.easeInOut(duration: 0.3), value: message.id)
        }
    }

    // MARK: - Controls Section

    private var controlsSection: some View {
        VStack(spacing: 16) {
            // Current transcript display
            if !self.viewModel.currentTranscript.isEmpty {
                self.transcriptDisplay
            }

            // Error display
            if let error = viewModel.error {
                self.errorDisplay(error)
            }

            // Control buttons with pulsing rings and hold hint
            ZStack {
                // Pulsing rings for VAD listening state
                if self.micButtonState == .vadListening {
                    PulsingRings(color: self.projectColor, size: 70)
                }

                // Control buttons
                HStack(spacing: 24) {
                    self.settingsButton
                    self.micButton
                    self.sendButton
                }
            }
            .padding(.vertical, 12)

            // Hold hint
            if self.viewModel.isHoldingMic {
                HoldHint(isVisible: self.showHoldHint)
            }

            // VOD indicator
            if self.viewModel.enableVOD, self.viewModel.vodRecordingURL != nil {
                self.vodIndicator
            }
        }
        .onChange(of: self.viewModel.isHoldingMic) { _, isHolding in
            if isHolding {
                Task {
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    withAnimation {
                        self.showHoldHint = true
                    }
                }
            } else {
                withAnimation {
                    self.showHoldHint = false
                }
            }
        }
        .sheet(isPresented: self.$isShowingSettings) {
            NavigationView {
                if let storage = aiConfigStorage {
                    VoiceCallSettingsWrapper(storage: storage) {
                        self.isShowingSettings = false
                    }
                } else {
                    Text("Settings unavailable")
                }
            }
            .presentationDetents([.medium, .large])
        }
    }

    private var settingsButton: some View {
        Button {
            self.isShowingSettings = true
        } label: {
            VStack(spacing: 4) {
                Image(systemName: "gear")
                    .font(.title3)
                Text("Settings")
                    .font(.caption2)
            }
            .foregroundStyle(.white)
            .frame(width: 60)
        }
    }

    private var micButton: some View {
        MicButton(
            state: self.micButtonState,
            audioLevel: self.viewModel.audioLevel,
            projectColor: self.projectColor,
            onTap: {
                Task {
                    // In VAD mode, tap toggles mute instead of recording
                    if self.isVADMode {
                        self.hapticManager.settingsToggle()
                        self.viewModel.toggleMute()
                    } else {
                        self.handleMicTap()
                        await self.viewModel.toggleRecording()
                    }
                }
            },
            onLongPressStart: {
                Task {
                    self.handleLongPressStart()
                    await self.viewModel.startHoldingMic()
                }
            },
            onLongPressEnd: {
                Task {
                    self.handleLongPressEnd()
                    await self.viewModel.stopHoldingMic()
                }
            }
        )
    }

    private var sendButton: some View {
        Button {
            Task {
                self.hapticManager.messageSent()
                await self.viewModel.sendMessage()
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: "paperplane.fill")
                    .font(.title3)
                Text("Send")
                    .font(.caption2)
            }
            .foregroundStyle(self.viewModel.canSend ? .white : .white.opacity(0.3))
            .frame(width: 60)
        }
        .disabled(!self.viewModel.canSend)
    }

    private var transcriptDisplay: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Your message:")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))

            Text(self.viewModel.currentTranscript)
                .font(.body)
                .foregroundStyle(.white)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private var vodIndicator: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color.red)
                .frame(width: 8, height: 8)
                .overlay {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                        .opacity(0.5)
                        .scaleEffect(1.5)
                        .animation(
                            .easeInOut(duration: 1.0).repeatForever(autoreverses: true),
                            value: self.viewModel.isCallActive
                        )
                }

            Text("Recording call")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.black.opacity(0.3))
        .clipShape(Capsule())
    }

    private func errorDisplay(_ error: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
            Text(error)
                .font(.caption)
                .foregroundStyle(.white)
        }
        .padding(8)
        .background(Color.red.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private func handleStateChange(from oldState: CallState, to newState: CallState) {
        switch newState {
        case .playingResponse where oldState != .playingResponse:
            self.hapticManager.ttsStarted()
        case .listening where oldState == .playingResponse:
            break
        default:
            break
        }
    }

    private func handleMicTap() {
        if self.viewModel.state == .recording {
            self.hapticManager.recordingStopped()
        } else {
            self.hapticManager.recordingStarted()
        }
    }

    private func handleLongPressStart() {
        self.hapticManager.tapHoldBegan()
    }

    private func handleLongPressEnd() {
        self.hapticManager.tapHoldReleased()
    }
}

// swiftlint:enable type_body_length

// MARK: - Preview

#Preview {
    Text("Call View Preview")
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
}
