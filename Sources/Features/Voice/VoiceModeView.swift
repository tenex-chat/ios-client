//
// VoiceModeView.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import NDKSwiftCore
import NDKSwiftUI
import SwiftUI
import TENEXCore

// MARK: - VoiceModeView

/// Full-screen voice mode conversation view
/// Displays agent avatar, audio visualizer, status, and controls
public struct VoiceModeView: View {
    // MARK: Lifecycle

    /// Initialize voice mode view
    /// - Parameters:
    ///   - viewModel: Voice mode view model
    ///   - ndk: NDK instance for profile pictures
    ///   - projectColor: Project accent color
    ///   - onDismiss: Callback when voice mode is dismissed
    public init(
        viewModel: VoiceModeViewModel,
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
            self.contentStack
        }
        .preferredColorScheme(.dark)
    }

    // MARK: Private

    @State private var viewModel: VoiceModeViewModel

    private let ndk: NDK
    private let projectColor: Color
    private let onDismiss: () -> Void

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [Color.black, self.projectColor.opacity(0.3), Color.black],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private var contentStack: some View {
        VStack(spacing: 0) {
            self.header
                .padding(.horizontal)
                .padding(.top)

            Spacer()
            self.mainContent
            Spacer()

            self.voiceControls
                .padding(.bottom, 40)
        }
    }

    private var voiceControls: some View {
        VoiceControlsView(
            state: self.viewModel.state,
            audioLevel: self.viewModel.audioLevel,
            canSend: self.viewModel.canSend,
            onEndCall: {
                Task {
                    await self.viewModel.endCall()
                    self.onDismiss()
                }
            },
            onToggleMic: {
                Task {
                    await self.viewModel.toggleRecording()
                }
            },
            onSend: {
                Task {
                    await self.viewModel.sendMessage()
                }
            }
        )
    }

    private var header: some View {
        HStack {
            // Close button
            Button {
                Task {
                    await self.viewModel.endCall()
                    self.onDismiss()
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(Color.white.opacity(0.2))
                    .clipShape(Circle())
            }

            Spacer()

            // Agent selector
            if self.viewModel.agents.count > 1 {
                self.agentSelector
            }
        }
    }

    private var agentSelector: some View {
        Menu {
            ForEach(self.viewModel.agents) { agent in
                Button {
                    self.viewModel.selectAgent(agent)
                } label: {
                    HStack {
                        Text(agent.name)
                        if agent.id == self.viewModel.selectedAgent?.id {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 8) {
                Text(self.viewModel.selectedAgent?.name ?? "Select Agent")
                    .font(.subheadline)
                    .foregroundStyle(.white)
                Image(systemName: "chevron.down")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.2))
            .clipShape(Capsule())
        }
    }

    private var mainContent: some View {
        VStack(spacing: 40) {
            // Agent avatar or visualizer
            ZStack {
                // Visualizer behind avatar
                VoiceVisualizerView(
                    audioLevel: self.viewModel.audioLevel,
                    isActive: self.viewModel.state == .recording || self.viewModel.state == .playing,
                    color: self.projectColor,
                    size: 140
                )

                // Agent avatar on top
                if let agent = viewModel.selectedAgent {
                    self.agentAvatar(for: agent)
                }
            }

            // Status display
            VoiceStatusView(
                state: self.viewModel.state,
                transcript: self.viewModel.transcript,
                error: self.viewModel.error,
                agentName: self.viewModel.selectedAgent?.name
            )
        }
    }

    private func agentAvatar(for agent: ProjectAgent) -> some View {
        NDKUIProfilePicture(ndk: self.ndk, pubkey: agent.pubkey, size: 80)
    }
}

// MARK: - Preview

#Preview {
    // Mock preview - in real use, provide actual dependencies
    Text("Voice Mode Preview")
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
}
