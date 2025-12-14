//
// VoiceVisualizerView.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import SwiftUI

// MARK: - VoiceVisualizerView

/// Animated orb visualization for voice mode
/// Displays pulsing rings and scales based on audio level
public struct VoiceVisualizerView: View {
    // MARK: Lifecycle

    /// Initialize the voice visualizer
    /// - Parameters:
    ///   - audioLevel: Current audio level (0.0 to 1.0)
    ///   - isActive: Whether actively recording or playing
    ///   - color: Accent color for the orb
    ///   - size: Size of the orb
    public init(
        audioLevel: Double,
        isActive: Bool,
        color: Color = .blue,
        size: CGFloat = 120
    ) {
        self.audioLevel = audioLevel
        self.isActive = isActive
        self.color = color
        self.size = size
    }

    // MARK: Public

    public var body: some View {
        ZStack {
            pulseRings
            orbGlow
            coreOrb
            innerLight
        }
        .animation(.easeOut(duration: 0.1), value: audioLevel)
        .animation(.easeInOut(duration: 0.3), value: isActive)
        .onAppear {
            startPulseAnimation()
        }
    }

    // MARK: Private

    @State private var pulseScale: CGFloat = 0

    private let audioLevel: Double
    private let isActive: Bool
    private let color: Color
    private let size: CGFloat

    @ViewBuilder private var pulseRings: some View {
        if isActive {
            ForEach(0 ..< 3, id: \.self) { index in
                Circle()
                    .stroke(color.opacity(0.2 - Double(index) * 0.05), lineWidth: 2)
                    .frame(
                        width: size + CGFloat(index) * 30 + pulseScale,
                        height: size + CGFloat(index) * 30 + pulseScale
                    )
                    .scaleEffect(1.0 + audioLevel * 0.2)
            }
        }
    }

    private var orbGlow: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        color.opacity(0.6),
                        color.opacity(0.3),
                        color.opacity(0.1),
                        .clear,
                    ],
                    center: .center,
                    startRadius: size * 0.3,
                    endRadius: size * 0.6
                )
            )
            .frame(width: size * 1.5, height: size * 1.5)
            .scaleEffect(1.0 + audioLevel * 0.3)
    }

    private var coreOrb: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        color.opacity(0.9),
                        color.opacity(0.7),
                        color.opacity(0.5),
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: size * 0.4
                )
            )
            .frame(width: size * 0.8, height: size * 0.8)
            .scaleEffect(1.0 + audioLevel * 0.15)
    }

    private var innerLight: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        .white.opacity(0.8),
                        .white.opacity(0.4),
                        .clear,
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: size * 0.2
                )
            )
            .frame(width: size * 0.4, height: size * 0.4)
            .scaleEffect(isActive ? 1.0 + audioLevel * 0.2 : 0.8)
    }

    private func startPulseAnimation() {
        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
            pulseScale = 20
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 40) {
        VoiceVisualizerView(
            audioLevel: 0.3,
            isActive: true,
            color: .blue
        )

        VoiceVisualizerView(
            audioLevel: 0.7,
            isActive: true,
            color: .green
        )

        VoiceVisualizerView(
            audioLevel: 0.0,
            isActive: false,
            color: .purple
        )
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.black)
}
