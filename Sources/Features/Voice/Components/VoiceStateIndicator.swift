//
// VoiceStateIndicator.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import SwiftUI

struct VoiceStateIndicator: View {
    // MARK: Lifecycle

    init(state: CallState) {
        self.state = state
    }

    // MARK: Internal

    let state: CallState

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(self.statusColor)
                .frame(width: 8, height: 8)
                .opacity(self.shouldPulse ? self.pulseOpacity : 1.0)
                .animation(
                    self.shouldPulse ? .easeInOut(duration: 1.0).repeatForever(autoreverses: true) : nil,
                    value: self.pulseOpacity
                )
                .onAppear {
                    if self.shouldPulse {
                        self.pulseOpacity = 0.6
                    }
                }

            Text(self.statusText)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.8))
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    // MARK: Private

    @State private var pulseOpacity = 1.0

    private var statusColor: Color {
        switch self.state {
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
        switch self.state {
        case .idle:
            "Ready"
        case .connecting:
            "Connecting..."
        case .listening:
            "Listening"
        case .recording:
            "Recording"
        case .processingSTT:
            "Processing"
        case .waitingForAgent:
            "Waiting"
        case .playingResponse:
            "Speaking"
        case .ended:
            "Ended"
        }
    }

    private var shouldPulse: Bool {
        switch self.state {
        case .listening,
             .recording,
             .connecting:
            true
        default:
            false
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        VoiceStateIndicator(state: .idle)
        VoiceStateIndicator(state: .connecting)
        VoiceStateIndicator(state: .listening)
        VoiceStateIndicator(state: .recording)
        VoiceStateIndicator(state: .processingSTT)
        VoiceStateIndicator(state: .waitingForAgent)
        VoiceStateIndicator(state: .playingResponse)
        VoiceStateIndicator(state: .ended)
    }
    .padding()
    .background(Color.black)
}
