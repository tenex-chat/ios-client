//
// CallView.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import NDKSwiftCore
import SwiftUI
import TENEXCore

// MARK: - CallView

// swiftlint:disable type_body_length

/// Enhanced call view with auto-TTS, STT, and VOD recording
/// Displays agent avatar, conversation history, audio controls, and status
public struct CallView: View {
    // MARK: Lifecycle

    /// Initialize call view
    /// - Parameters:
    ///   - viewModel: Call view model
    ///   - ndk: NDK instance for profile pictures
    ///   - projectColor: Project accent color
    ///   - onDismiss: Callback when call is dismissed
    public init(
        viewModel: CallViewModel,
        ndk: NDK,
        projectColor: Color = .blue,
        onDismiss: @escaping () -> Void
    ) {
        _viewModel = State(initialValue: viewModel)
        self.ndk = ndk
        self.projectColor = projectColor
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
            // Track when call session started
            self.sessionStartTime = Date()

            // Start call when view appears
            if self.viewModel.state == .idle {
                await self.viewModel.startCall()
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

    // Note: NDK instance reserved for future profile picture support
    private let ndk: NDK
    private let projectColor: Color
    private let onDismiss: () -> Void

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
        let hue = Double(abs(hash) % 360) / 360.0
        return Color(hue: hue, saturation: 0.6, brightness: 0.7)
    }

    private var micButtonState: MicButtonState {
        if self.viewModel.isHoldingMic {
            return .held
        }

        switch self.viewModel.state {
        case .idle:
            return self.viewModel.vadMode == .auto || self.viewModel.vadMode == .autoWithHold ? .vadListening : .idle
        case .listening:
            return self.viewModel.vadMode == .auto || self.viewModel.vadMode == .autoWithHold ? .vadListening : .idle
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
                self.waitingForCallView
                Spacer()
            } else {
                self.conversationView
                    .padding(.horizontal)
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
            self.agentStatusInfo
            self.agentAvatar.padding(.leading, 12)
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
                    .font(.system(size: 14, weight: .semibold))
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
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
        }
    }

    // MARK: - Waiting View

    private var waitingForCallView: some View {
        VStack(spacing: 24) {
            // Animated visualizer
            VoiceVisualizerView(
                audioLevel: self.viewModel.audioLevel,
                isActive: self.viewModel.state == .connecting || self.viewModel.state == .playingResponse,
                color: self.projectColor,
                size: 120
            )

            Text(self.viewModel
                .state == .connecting ? "Connecting to \(self.viewModel.agent.name)..." : "Ready to start")
                .font(.title3)
                .foregroundStyle(.white)
        }
    }

    // MARK: - Conversation View

    private var conversationView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(self.sessionMessages) { message in
                        MessageBubble(
                            message: message,
                            accentColor: self.projectColor,
                            userPubkey: self.viewModel.userPubkey
                        ) {
                            Task {
                                await self.viewModel.replayMessage(message.id)
                            }
                        }
                        .id(message.id)
                    }
                }
                .padding(.vertical, 16)
            }
            .onChange(of: self.sessionMessages.count) { _, _ in
                // Auto-scroll to bottom when new message arrives
                if let lastMessage = sessionMessages.last {
                    withAnimation {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    // MARK: - Controls Section

    private var controlsSection: some View {
        // swiftlint:disable:next closure_body_length
        VStack(spacing: 16) {
            // Current transcript display
            if !self.viewModel.currentTranscript.isEmpty {
                self.transcriptDisplay
            }

            // Error display
            if let error = viewModel.error {
                self.errorDisplay(error)
            }

            // Audio visualizer
            if self.viewModel.state == .recording {
                VoiceVisualizerView(
                    audioLevel: self.viewModel.audioLevel,
                    isActive: true,
                    color: self.projectColor,
                    size: 80
                )
                .transition(.scale)
            }

            // Control buttons with pulsing rings and hold hint
            ZStack {
                // Pulsing rings for VAD listening state
                if self.micButtonState == .vadListening {
                    PulsingRings(color: self.projectColor, size: 70)
                }

                // Control buttons
                HStack(spacing: 24) {
                    self.autoTTSButton
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
    }

    private var autoTTSButton: some View {
        Button {
            self.hapticManager.settingsToggle()
            self.viewModel.toggleAutoTTS()
        } label: {
            VStack(spacing: 4) {
                Image(systemName: self.viewModel.autoTTS ? "speaker.wave.3.fill" : "speaker.slash.fill")
                    .font(.system(size: 20))
                Text(self.viewModel.autoTTS ? "Auto TTS" : "TTS Off")
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
                    self.handleMicTap()
                    await self.viewModel.toggleRecording()
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
                    .font(.system(size: 20))
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
