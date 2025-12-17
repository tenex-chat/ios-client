//
// AgentSpeakingOverlay.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import NDKSwiftCore
import NDKSwiftUI
import SwiftUI

// MARK: - AgentOverlayState

enum AgentOverlayState {
    case hidden
    case processing
    case speaking
    case paused
}

// MARK: - AgentSpeakingOverlay

struct AgentSpeakingOverlay: View {
    // MARK: Lifecycle

    init(
        ndk: NDK,
        agentPubkey: String,
        agentName: String,
        state: AgentOverlayState,
        onTap: @escaping () -> Void,
        onLongPress: @escaping () -> Void
    ) {
        self.ndk = ndk
        self.agentPubkey = agentPubkey
        self.agentName = agentName
        self.state = state
        self.onTap = onTap
        self.onLongPress = onLongPress
    }

    // MARK: Internal

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            // Agent avatar with animations
            ZStack {
                // Ripple animation when speaking
                if self.state == .speaking {
                    self.speakingRipples
                }

                // Processing animation (pulsing dots around avatar)
                if self.state == .processing {
                    self.processingAnimation
                }

                // Avatar circle
                self.avatarCircle

                // Pause icon overlay
                if self.state == .paused {
                    self.pauseOverlay
                }
            }

            // Status text
            Text(self.statusText)
                .font(.headline)
                .foregroundStyle(.white)

            // Hint text
            Text(self.hintText)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.7))
        .contentShape(Rectangle())
        .onTapGesture(perform: self.onTap)
        .onLongPressGesture(minimumDuration: 0.5, perform: self.onLongPress)
    }

    // MARK: Private

    @State private var rippleScale: [CGFloat] = [1.0, 1.0, 1.0]
    @State private var rippleOpacity: [Double] = [0.4, 0.3, 0.2]
    @State private var dotScale: CGFloat = 1.0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let ndk: NDK
    private let agentPubkey: String
    private let agentName: String
    private let state: AgentOverlayState
    private let onTap: () -> Void
    private let onLongPress: () -> Void

    private let avatarSize: CGFloat = 100

    private var statusText: String {
        switch self.state {
        case .processing:
            "\(self.agentName) is thinking..."
        case .speaking:
            "\(self.agentName) is speaking"
        case .paused:
            "Paused"
        case .hidden:
            ""
        }
    }

    private var hintText: String {
        switch self.state {
        case .speaking:
            "Tap to pause \u{2022} Hold to interrupt"
        case .paused:
            "Tap to resume \u{2022} Hold to interrupt"
        case .processing:
            "Hold to cancel"
        case .hidden:
            ""
        }
    }

    @ViewBuilder private var speakingRipples: some View {
        ForEach(0 ..< 3, id: \.self) { index in
            Circle()
                .stroke(Color.purple.opacity(self.rippleOpacity[index]), lineWidth: 2)
                .frame(
                    width: self.avatarSize + CGFloat(index + 1) * 30,
                    height: self.avatarSize + CGFloat(index + 1) * 30
                )
                .scaleEffect(self.rippleScale[index])
                .onAppear {
                    guard !self.reduceMotion else {
                        return
                    }
                    withAnimation(
                        .easeOut(duration: 1.5)
                            .repeatForever(autoreverses: false)
                            .delay(Double(index) * 0.4)
                    ) {
                        self.rippleScale[index] = 1.3
                        self.rippleOpacity[index] = 0
                    }
                }
        }
    }

    @ViewBuilder private var processingAnimation: some View {
        // Pulsing dots around the avatar
        ForEach(0 ..< 3, id: \.self) { index in
            Circle()
                .fill(.white.opacity(0.8))
                .frame(width: 8, height: 8)
                .offset(y: -(self.avatarSize / 2 + 20))
                .rotationEffect(.degrees(Double(index) * 120))
                .scaleEffect(self.dotScale)
        }
        .onAppear {
            guard !self.reduceMotion else {
                return
            }
            withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                self.dotScale = 0.5
            }
        }
    }

    private var avatarCircle: some View {
        NDKUIProfilePicture(ndk: self.ndk, pubkey: self.agentPubkey, size: self.avatarSize)
            .shadow(color: .purple.opacity(0.5), radius: 20)
    }

    private var pauseOverlay: some View {
        ZStack {
            Circle()
                .fill(.black.opacity(0.5))
                .frame(width: self.avatarSize, height: self.avatarSize)

            Image(systemName: "pause.fill")
                .font(.largeTitle)
                .foregroundStyle(.white)
        }
    }
}

// MARK: - Preview

#Preview {
    // Mock NDK instance for preview
    let ndk = NDK(relayURLs: ["wss://relay.damus.io"])
    VStack(spacing: 0) {
        AgentSpeakingOverlay(
            ndk: ndk,
            agentPubkey: "npub1test",
            agentName: "Luna",
            state: .speaking,
            onTap: {},
            onLongPress: {}
        )
    }
    .preferredColorScheme(.dark)
}

#Preview("Processing") {
    let ndk = NDK(relayURLs: ["wss://relay.damus.io"])
    VStack(spacing: 0) {
        AgentSpeakingOverlay(
            ndk: ndk,
            agentPubkey: "npub1test",
            agentName: "Luna",
            state: .processing,
            onTap: {},
            onLongPress: {}
        )
    }
    .preferredColorScheme(.dark)
}

#Preview("Paused") {
    let ndk = NDK(relayURLs: ["wss://relay.damus.io"])
    VStack(spacing: 0) {
        AgentSpeakingOverlay(
            ndk: ndk,
            agentPubkey: "npub1test",
            agentName: "Luna",
            state: .paused,
            onTap: {},
            onLongPress: {}
        )
    }
    .preferredColorScheme(.dark)
}
