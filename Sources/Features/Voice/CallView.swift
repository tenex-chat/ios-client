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
            backgroundGradient
            contentView
        }
        .preferredColorScheme(.dark)
        .task {
            // Start call when view appears
            if viewModel.state == .idle {
                await viewModel.startCall()
            }
        }
    }

    // MARK: Private

    @State private var viewModel: CallViewModel

    // Note: NDK instance reserved for future profile picture support
    private let ndk: NDK
    private let projectColor: Color
    private let onDismiss: () -> Void

    private var agentInitials: String {
        let words = viewModel.agent.name.split(separator: " ")
        if words.count >= 2 {
            return String(words[0].prefix(1) + words[1].prefix(1)).uppercased()
        } else if let first = words.first {
            return String(first.prefix(2)).uppercased()
        }
        return "?"
    }

    private var agentColor: Color {
        let hash = viewModel.agent.pubkey.hashValue
        let hue = Double(abs(hash) % 360) / 360.0
        return Color(hue: hue, saturation: 0.6, brightness: 0.7)
    }

    private var statusColor: Color {
        switch viewModel.state {
        case .idle,
             .ended:
            .gray
        case .connecting:
            .yellow
        case .listening,
             .recording,
             .processingSTT:
            .green
        case .waitingForAgent,
             .playingResponse:
            .blue
        }
    }

    private var statusText: String {
        switch viewModel.state {
        case .idle:
            "Not started"
        case .connecting:
            "Connecting..."
        case .listening:
            "Listening"
        case .recording:
            "Recording"
        case .processingSTT:
            "Processing"
        case .waitingForAgent:
            "Waiting for response"
        case .playingResponse:
            "Speaking"
        case .ended:
            "Call ended"
        }
    }

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [Color.black, projectColor.opacity(0.3), Color.black],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private var contentView: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal)
                .padding(.top)

            if viewModel.messages.isEmpty {
                Spacer()
                waitingForCallView
                Spacer()
            } else {
                conversationView
                    .padding(.horizontal)
            }

            controlsSection
                .padding(.horizontal)
                .padding(.bottom, 40)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            endCallButton
            Spacer()
            agentStatusInfo
            agentAvatar.padding(.leading, 12)
        }
    }

    private var endCallButton: some View {
        Button {
            Task {
                await viewModel.endCall()
                onDismiss()
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
            Text(viewModel.agent.name)
                .font(.headline)
                .foregroundStyle(.white)
            HStack(spacing: 6) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
    }

    private var agentAvatar: some View {
        ZStack {
            Circle()
                .fill(agentColor)
                .frame(width: 50, height: 50)

            Text(agentInitials)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
        }
    }

    // MARK: - Waiting View

    private var waitingForCallView: some View {
        VStack(spacing: 24) {
            // Animated visualizer
            VoiceVisualizerView(
                audioLevel: viewModel.audioLevel,
                isActive: viewModel.state == .connecting || viewModel.state == .playingResponse,
                color: projectColor,
                size: 120
            )

            Text(viewModel.state == .connecting ? "Connecting to \(viewModel.agent.name)..." : "Ready to start")
                .font(.title3)
                .foregroundStyle(.white)
        }
    }

    // MARK: - Conversation View

    private var conversationView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(viewModel.messages) { message in
                        MessageBubble(
                            message: message,
                            accentColor: projectColor
                        ) {
                            Task {
                                await viewModel.replayMessage(message.id)
                            }
                        }
                        .id(message.id)
                    }
                }
                .padding(.vertical, 16)
            }
            .onChange(of: viewModel.messages.count) { _, _ in
                // Auto-scroll to bottom when new message arrives
                if let lastMessage = viewModel.messages.last {
                    withAnimation {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    // MARK: - Controls Section

    private var controlsSection: some View {
        VStack(spacing: 16) {
            // Current transcript display
            if !viewModel.currentTranscript.isEmpty {
                transcriptDisplay
            }

            // Error display
            if let error = viewModel.error {
                errorDisplay(error)
            }

            // Audio visualizer
            if viewModel.state == .recording {
                VoiceVisualizerView(
                    audioLevel: viewModel.audioLevel,
                    isActive: true,
                    color: projectColor,
                    size: 80
                )
                .transition(.scale)
            }

            // Control buttons
            HStack(spacing: 24) {
                autoTTSButton
                recordButton
                sendButton
            }
            .padding(.vertical, 12)

            // VOD indicator
            if viewModel.enableVOD, viewModel.vodRecordingURL != nil {
                vodIndicator
            }
        }
    }

    private var autoTTSButton: some View {
        Button {
            viewModel.toggleAutoTTS()
        } label: {
            VStack(spacing: 4) {
                Image(systemName: viewModel.autoTTS ? "speaker.wave.3.fill" : "speaker.slash.fill")
                    .font(.system(size: 20))
                Text(viewModel.autoTTS ? "Auto TTS" : "TTS Off")
                    .font(.caption2)
            }
            .foregroundStyle(.white)
            .frame(width: 60)
        }
    }

    private var recordButton: some View {
        Button {
            Task {
                await viewModel.toggleRecording()
            }
        } label: {
            ZStack {
                Circle()
                    .fill(viewModel.state == .recording ? Color.red : projectColor)
                    .frame(width: 70, height: 70)

                if viewModel.state == .recording {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.white)
                        .frame(width: 24, height: 24)
                } else {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(.white)
                }
            }
            .shadow(color: (viewModel.state == .recording ? Color.red : projectColor).opacity(0.5), radius: 10)
        }
        .disabled(!viewModel.canRecord && viewModel.state != .recording)
    }

    private var sendButton: some View {
        Button {
            Task {
                await viewModel.sendMessage()
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 20))
                Text("Send")
                    .font(.caption2)
            }
            .foregroundStyle(viewModel.canSend ? .white : .white.opacity(0.3))
            .frame(width: 60)
        }
        .disabled(!viewModel.canSend)
    }

    private var transcriptDisplay: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Your message:")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))

            Text(viewModel.currentTranscript)
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
                            value: viewModel.isCallActive
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
}

// swiftlint:enable type_body_length

// MARK: - Preview

#Preview {
    Text("Call View Preview")
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
}
