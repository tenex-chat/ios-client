//
// VoiceStatusView.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import SwiftUI

// MARK: - VoiceStatusView

/// Displays the current voice call status and transcript
public struct VoiceStatusView: View {
    // MARK: Lifecycle

    /// Initialize voice status view
    /// - Parameters:
    ///   - state: Current voice call state
    ///   - transcript: Current transcript text
    ///   - error: Error message if any
    ///   - agentName: Name of the selected agent
    public init(
        state: VoiceCallState,
        transcript: String,
        error: String?,
        agentName: String?
    ) {
        self.state = state
        self.transcript = transcript
        self.error = error
        self.agentName = agentName
    }

    // MARK: Public

    public var body: some View {
        VStack(spacing: 16) {
            // Status indicator
            statusIndicator

            // Agent name
            if let agentName {
                Text(agentName)
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }

            // Transcript or status message
            if let error {
                errorView(error)
            } else if !transcript.isEmpty {
                transcriptView
            } else {
                statusMessage
            }
        }
        .padding(.horizontal, 24)
    }

    // MARK: Private

    @State private var pulseScale: CGFloat = 1.0

    private let state: VoiceCallState
    private let transcript: String
    private let error: String?
    private let agentName: String?

    private var statusText: String {
        switch state {
        case .recording:
            "Listening..."
        case .processing:
            "Processing..."
        case .playing:
            "Agent speaking..."
        case .idle:
            transcript.isEmpty ? "Tap mic to start" : "Ready to send"
        }
    }

    private var statusColor: Color {
        switch state {
        case .recording:
            .red
        case .processing:
            .orange
        case .playing:
            .blue
        case .idle:
            .secondary
        }
    }

    @ViewBuilder private var statusIndicator: some View {
        HStack(spacing: 8) {
            // Animated indicator
            switch state {
            case .recording:
                Circle()
                    .fill(Color.red)
                    .frame(width: 10, height: 10)
                    .overlay(
                        Circle()
                            .stroke(Color.red.opacity(0.5), lineWidth: 2)
                            .scaleEffect(pulseScale)
                            .opacity(2 - pulseScale)
                    )
                    .onAppear {
                        withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: false)) {
                            pulseScale = 2.0
                        }
                    }

            case .processing:
                ProgressView()
                    .scaleEffect(0.8)

            case .playing:
                Image(systemName: "speaker.wave.2.fill")
                    .foregroundStyle(.blue)

            case .idle:
                Image(systemName: "mic")
                    .foregroundStyle(.secondary)
            }

            // Status text
            Text(statusText)
                .font(.subheadline)
                .foregroundStyle(statusColor)
        }
    }

    private var transcriptView: some View {
        ScrollView {
            Text(transcript)
                .font(.body)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxHeight: 150)
    }

    private var statusMessage: some View {
        Text(state == .idle ? "Speak or tap the mic button" : "")
            .font(.subheadline)
            .foregroundStyle(.tertiary)
    }

    private func errorView(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.red)
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 40) {
        VoiceStatusView(
            state: .idle,
            transcript: "",
            error: nil,
            agentName: "Assistant"
        )

        VoiceStatusView(
            state: .recording,
            transcript: "",
            error: nil,
            agentName: "Coder"
        )

        VoiceStatusView(
            state: .processing,
            transcript: "Hello, can you help me with this code?",
            error: nil,
            agentName: "Reviewer"
        )

        VoiceStatusView(
            state: .idle,
            transcript: "",
            error: "Microphone permission denied",
            agentName: nil
        )
    }
    .padding()
    .background(Color.black)
}
