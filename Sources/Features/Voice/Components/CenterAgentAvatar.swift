//
// CenterAgentAvatar.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import NDKSwiftCore
import NDKSwiftUI
import SwiftUI

struct CenterAgentAvatar: View {
    // MARK: Internal

    let ndk: NDK
    let agentPubkey: String
    let agentName: String
    let isSpeaking: Bool
    let isProcessing: Bool
    let isPaused: Bool
    let onTap: () -> Void
    let onLongPress: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                if self.isSpeaking {
                    self.speakingRipples
                }

                if self.isProcessing {
                    self.processingDots
                }

                self.avatarCircle

                if self.isPaused {
                    self.pauseOverlay
                }
            }
            .onAppear { self.startAnimations() }
            .onChange(of: self.isSpeaking) { _, _ in self.startAnimations() }
            .onChange(of: self.isProcessing) { _, _ in self.startAnimations() }
            .onChange(of: self.isPaused) { _, _ in self.startAnimations() }
            .contentShape(Circle())
            .onTapGesture(perform: self.onTap)
            .onLongPressGesture(minimumDuration: 0.5, perform: self.onLongPress)

            Text(self.statusText)
                .font(.headline)
                .foregroundStyle(.white)

            if !self.hintText.isEmpty {
                Text(self.hintText)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: self.isSpeaking)
        .animation(.easeInOut(duration: 0.3), value: self.isPaused)
    }

    // MARK: Private

    @State private var speakingRippleScale: [CGFloat] = [1.0, 1.0, 1.0]
    @State private var speakingRippleOpacity: [Double] = [0.4, 0.3, 0.2]
    @State private var processingRotation: Double = 0

    private let avatarSize: CGFloat = 120

    private var statusText: String {
        if self.isPaused {
            return "Paused"
        }
        if self.isSpeaking {
            return "\(self.agentName) is speaking"
        }
        if self.isProcessing {
            return "\(self.agentName) is thinking..."
        }
        return ""
    }

    private var hintText: String {
        if self.isSpeaking {
            return "Tap to pause • Hold to interrupt"
        }
        if self.isPaused {
            return "Tap to resume • Hold to interrupt"
        }
        if self.isProcessing {
            return "Hold to cancel"
        }
        return ""
    }

    @ViewBuilder private var speakingRipples: some View {
        ForEach(0 ..< 3, id: \.self) { index in
            Circle()
                .stroke(Color.purple.opacity(0.4 - Double(index) * 0.1), lineWidth: 2)
                .frame(
                    width: self.avatarSize + CGFloat(index + 1) * 30,
                    height: self.avatarSize + CGFloat(index + 1) * 30
                )
                .scaleEffect(self.speakingRippleScale[index])
                .opacity(self.speakingRippleOpacity[index])
        }
    }

    @ViewBuilder private var processingDots: some View {
        ForEach(0 ..< 3, id: \.self) { index in
            Circle()
                .fill(.white.opacity(0.8))
                .frame(width: 8, height: 8)
                .offset(y: -80)
                .rotationEffect(.degrees(Double(index) * 120 + self.processingRotation))
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

    private func startAnimations() {
        if self.isSpeaking {
            for index in 0 ..< 3 {
                self.speakingRippleScale[index] = 1.0
                self.speakingRippleOpacity[index] = 0.4 - Double(index) * 0.1
            }
            withAnimation(.easeOut(duration: 1.5).repeatForever(autoreverses: false)) {
                for index in 0 ..< 3 {
                    self.speakingRippleScale[index] = 1.3
                    self.speakingRippleOpacity[index] = 0
                }
            }
        } else if self.isProcessing {
            self.processingRotation = 0
            withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                self.processingRotation = 360
            }
        }
    }
}
