//
// VoiceControlsView.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import SwiftUI

// MARK: - VoiceControlsView

/// Control buttons for voice mode: end call, mic toggle, send
public struct VoiceControlsView: View {
    // MARK: Lifecycle

    /// Initialize voice controls
    /// - Parameters:
    ///   - state: Current voice call state
    ///   - audioLevel: Current audio level for mic visualization
    ///   - canSend: Whether send button should be enabled
    ///   - onEndCall: End call action
    ///   - onToggleMic: Toggle microphone action
    ///   - onSend: Send message action
    public init(
        state: VoiceCallState,
        audioLevel: Double,
        canSend: Bool,
        onEndCall: @escaping () -> Void,
        onToggleMic: @escaping () -> Void,
        onSend: @escaping () -> Void
    ) {
        self.state = state
        self.audioLevel = audioLevel
        self.canSend = canSend
        self.onEndCall = onEndCall
        self.onToggleMic = onToggleMic
        self.onSend = onSend
    }

    // MARK: Public

    public var body: some View {
        HStack(spacing: 40) {
            // End call button
            endCallButton

            // Mic toggle button
            micButton

            // Send button
            sendButton
        }
        .padding(.horizontal, 40)
        .padding(.vertical, 20)
    }

    // MARK: Private

    private let state: VoiceCallState
    private let audioLevel: Double
    private let canSend: Bool
    private let onEndCall: () -> Void
    private let onToggleMic: () -> Void
    private let onSend: () -> Void

    private var micIcon: String {
        switch state {
        case .recording:
            "mic.fill"
        case .processing:
            "waveform"
        case .playing:
            "speaker.wave.2.fill"
        case .idle:
            "mic"
        }
    }

    private var micBackgroundColor: Color {
        switch state {
        case .recording:
            Color.red
        case .processing:
            Color.orange
        case .playing:
            Color.blue
        case .idle:
            Color.gray.opacity(0.3)
        }
    }

    private var micForegroundColor: Color {
        switch state {
        case .recording,
             .processing,
             .playing:
            .white
        case .idle:
            .primary
        }
    }

    private var endCallButton: some View {
        Button(action: onEndCall) {
            Image(systemName: "phone.down.fill")
                .font(.system(size: 24))
                .foregroundStyle(.white)
                .frame(width: 64, height: 64)
                .background(Color.red)
                .clipShape(Circle())
        }
    }

    private var micButton: some View {
        Button(action: onToggleMic) {
            ZStack {
                // Audio level ring
                if state == .recording {
                    Circle()
                        .stroke(Color.red.opacity(0.3), lineWidth: 3)
                        .frame(width: 80 + audioLevel * 20, height: 80 + audioLevel * 20)
                        .animation(.easeOut(duration: 0.1), value: audioLevel)
                }

                // Mic button
                Image(systemName: micIcon)
                    .font(.system(size: 28))
                    .foregroundStyle(micForegroundColor)
                    .frame(width: 80, height: 80)
                    .background(micBackgroundColor)
                    .clipShape(Circle())
            }
        }
        .disabled(state == .processing || state == .playing)
    }

    private var sendButton: some View {
        Button(action: onSend) {
            Image(systemName: "arrow.up.circle.fill")
                .font(.system(size: 24))
                .foregroundStyle(canSend ? .white : .gray)
                .frame(width: 64, height: 64)
                .background(canSend ? Color.green : Color.gray.opacity(0.3))
                .clipShape(Circle())
        }
        .disabled(!canSend)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 40) {
        VoiceControlsView(
            state: .idle,
            audioLevel: 0.0,
            canSend: false,
            onEndCall: {},
            onToggleMic: {},
            onSend: {}
        )

        VoiceControlsView(
            state: .recording,
            audioLevel: 0.5,
            canSend: false,
            onEndCall: {},
            onToggleMic: {},
            onSend: {}
        )

        VoiceControlsView(
            state: .idle,
            audioLevel: 0.0,
            canSend: true,
            onEndCall: {},
            onToggleMic: {},
            onSend: {}
        )
    }
    .padding()
    .background(Color.black)
}
