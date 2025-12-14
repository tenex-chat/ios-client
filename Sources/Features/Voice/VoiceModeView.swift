//
// VoiceModeView.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import NDKSwiftCore
import SwiftUI

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
            backgroundGradient
            contentStack
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
            colors: [Color.black, projectColor.opacity(0.3), Color.black],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private var contentStack: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal)
                .padding(.top)

            Spacer()
            mainContent
            Spacer()

            voiceControls
                .padding(.bottom, 40)
        }
    }

    private var voiceControls: some View {
        VoiceControlsView(
            state: viewModel.state,
            audioLevel: viewModel.audioLevel,
            canSend: viewModel.canSend,
            onEndCall: {
                Task {
                    await viewModel.endCall()
                    onDismiss()
                }
            },
            onToggleMic: {
                Task {
                    await viewModel.toggleRecording()
                }
            },
            onSend: {
                Task {
                    await viewModel.sendMessage()
                }
            }
        )
    }

    private var header: some View {
        HStack {
            // Close button
            Button {
                Task {
                    await viewModel.endCall()
                    onDismiss()
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(Color.white.opacity(0.2))
                    .clipShape(Circle())
            }

            Spacer()

            // Agent selector
            if viewModel.agents.count > 1 {
                agentSelector
            }
        }
    }

    private var agentSelector: some View {
        Menu {
            ForEach(viewModel.agents) { agent in
                Button {
                    viewModel.selectAgent(agent)
                } label: {
                    HStack {
                        Text(agent.name)
                        if agent.id == viewModel.selectedAgent?.id {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 8) {
                Text(viewModel.selectedAgent?.name ?? "Select Agent")
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
                    audioLevel: viewModel.audioLevel,
                    isActive: viewModel.state == .recording || viewModel.state == .playing,
                    color: projectColor,
                    size: 140
                )

                // Agent avatar on top
                if let agent = viewModel.selectedAgent {
                    agentAvatar(for: agent)
                }
            }

            // Status display
            VoiceStatusView(
                state: viewModel.state,
                transcript: viewModel.transcript,
                error: viewModel.error,
                agentName: viewModel.selectedAgent?.name
            )
        }
    }

    private func agentAvatar(for agent: ProjectAgent) -> some View {
        ZStack {
            // Avatar circle
            Circle()
                .fill(agentColor(for: agent.pubkey))
                .frame(width: 80, height: 80)

            // Agent initials
            Text(agentInitials(agent.name))
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(.white)
        }
    }

    private func agentInitials(_ name: String) -> String {
        let words = name.split(separator: " ")
        if words.count >= 2 {
            return String(words[0].prefix(1) + words[1].prefix(1)).uppercased()
        } else if let first = words.first {
            return String(first.prefix(2)).uppercased()
        }
        return "?"
    }

    private func agentColor(for pubkey: String) -> Color {
        // Deterministic color from pubkey hash
        let hash = pubkey.hashValue
        let hue = Double(abs(hash) % 360) / 360.0
        return Color(hue: hue, saturation: 0.6, brightness: 0.7)
    }
}

// MARK: - Preview

#Preview {
    // Mock preview - in real use, provide actual dependencies
    Text("Voice Mode Preview")
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
}
