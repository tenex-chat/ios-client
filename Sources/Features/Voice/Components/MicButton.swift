//
// MicButton.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import SwiftUI

// MARK: - MicButtonState

enum MicButtonState {
    case idle
    case vadListening
    case recording
    case held
    case processing
    case playing
}

// MARK: - MicButton

struct MicButton: View {
    // MARK: Lifecycle

    init(
        state: MicButtonState,
        audioLevel: Double,
        projectColor: Color,
        onTap: @escaping () -> Void,
        onLongPressStart: @escaping () -> Void,
        onLongPressEnd: @escaping () -> Void
    ) {
        self.state = state
        self.audioLevel = audioLevel
        self.projectColor = projectColor
        self.onTap = onTap
        self.onLongPressStart = onLongPressStart
        self.onLongPressEnd = onLongPressEnd
    }

    // MARK: Internal

    @GestureState var isPressed = false

    let state: MicButtonState
    let audioLevel: Double
    let projectColor: Color
    let onTap: () -> Void
    let onLongPressStart: () -> Void
    let onLongPressEnd: () -> Void

    var body: some View {
        ZStack {
            // Audio level ring (recording or held states)
            if self.state == .recording || self.state == .held {
                Circle()
                    .stroke(self.ringColor.opacity(0.3), lineWidth: 3)
                    .frame(width: 70 + self.audioLevel * 20, height: 70 + self.audioLevel * 20)
                    .animation(self.reduceMotion ? nil : .easeOut(duration: 0.05), value: self.audioLevel)
            }

            // VAD indicator ring
            if self.state == .vadListening {
                Circle()
                    .stroke(Color.green.opacity(0.5), lineWidth: 2)
                    .frame(width: 74, height: 74)
                    .scaleEffect(self.vadPulseScale)
                    .animation(
                        self.reduceMotion ? nil : .easeInOut(duration: 2.0).repeatForever(autoreverses: true),
                        value: self.vadPulseScale
                    )
                    .onAppear {
                        self.vadPulseScale = 1.05
                    }
            }

            // Main button
            Circle()
                .fill(self.backgroundColor)
                .frame(width: 70, height: 70)
                .shadow(color: self.shadowColor.opacity(0.5), radius: 10)

            // Icon
            self.iconView
        }
        .scaleEffect(self.isPressed ? 0.95 : 1.0)
        .animation(.easeOut(duration: 0.1), value: self.isPressed)
        .simultaneousGesture(self.combinedGesture)
        .accessibilityLabel(self.accessibilityLabel)
        .accessibilityHint(self.accessibilityHint)
    }

    // MARK: Private

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var vadPulseScale: CGFloat = 1.0

    private var backgroundColor: Color {
        switch self.state {
        case .idle:
            self.projectColor
        case .vadListening:
            self.projectColor
        case .recording:
            .red
        case .held:
            .orange
        case .processing:
            self.projectColor.opacity(0.4)
        case .playing:
            .blue
        }
    }

    private var ringColor: Color {
        self.state == .held ? .orange : .red
    }

    private var shadowColor: Color {
        switch self.state {
        case .idle,
             .vadListening:
            self.projectColor
        case .recording:
            .red
        case .held:
            .orange
        case .processing:
            self.projectColor
        case .playing:
            .blue
        }
    }

    private var combinedGesture: some Gesture {
        LongPressGesture(minimumDuration: 0.3)
            .onEnded { _ in
                self.onLongPressStart()
            }
            .sequenced(before: DragGesture(minimumDistance: 0))
            .updating(self.$isPressed) { value, state, _ in
                switch value {
                case .first:
                    state = true
                case .second(true, _):
                    state = true
                default:
                    state = false
                }
            }
            .onEnded { value in
                switch value {
                case .second(true, _):
                    self.onLongPressEnd()
                default:
                    self.onTap()
                }
            }
    }

    private var accessibilityLabel: String {
        switch self.state {
        case .idle:
            "Microphone"
        case .vadListening:
            "Listening for speech"
        case .recording:
            "Recording"
        case .held:
            "Holding microphone open"
        case .processing:
            "Processing speech"
        case .playing:
            "Agent speaking"
        }
    }

    private var accessibilityHint: String {
        switch self.state {
        case .idle:
            "Tap to start recording"
        case .vadListening:
            "Speak to record, or tap to pause"
        case .recording:
            "Tap to stop recording"
        case .held:
            "Release to stop recording"
        case .processing:
            "Processing your speech"
        case .playing:
            "Tap to interrupt"
        }
    }

    @ViewBuilder private var iconView: some View {
        switch self.state {
        case .recording,
             .held:
            RoundedRectangle(cornerRadius: 8)
                .fill(.white)
                .frame(width: 24, height: 24)
                .transition(.opacity.combined(with: .scale(scale: 0.8)))
        case .processing:
            ProgressView()
                .tint(.white)
                .transition(.opacity.combined(with: .scale(scale: 0.8)))
        case .playing:
            Image(systemName: "speaker.wave.3.fill")
                .font(.system(size: 28))
                .foregroundStyle(.white)
                .transition(.opacity.combined(with: .scale(scale: 0.8)))
        default:
            Image(systemName: "mic.fill")
                .font(.system(size: 28))
                .foregroundStyle(.white)
                .transition(.opacity.combined(with: .scale(scale: 0.8)))
        }
    }
}

// swiftlint:disable:next closure_body_length
#Preview {
    // swiftlint:disable:next closure_body_length
    VStack(spacing: 40) {
        MicButton(
            state: .idle,
            audioLevel: 0.0,
            projectColor: .blue,
            onTap: {},
            onLongPressStart: {},
            onLongPressEnd: {}
        )

        MicButton(
            state: .vadListening,
            audioLevel: 0.0,
            projectColor: .blue,
            onTap: {},
            onLongPressStart: {},
            onLongPressEnd: {}
        )

        MicButton(
            state: .recording,
            audioLevel: 0.5,
            projectColor: .blue,
            onTap: {},
            onLongPressStart: {},
            onLongPressEnd: {}
        )

        MicButton(
            state: .held,
            audioLevel: 0.7,
            projectColor: .blue,
            onTap: {},
            onLongPressStart: {},
            onLongPressEnd: {}
        )
    }
    .padding()
    .background(Color.black)
}
