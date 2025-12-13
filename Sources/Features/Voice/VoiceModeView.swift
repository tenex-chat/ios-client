//
//  VoiceModeView.swift
//  TENEX
//
//  Created by Jules on 2024.
//

import SwiftUI
import TENEXCore

public struct VoiceModeView: View {
    @State private var viewModel = VoiceModeViewModel()
    @Environment(\.dismiss) private var dismiss

    public init() {}

    public var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)

            VStack(spacing: 40) {
                // Header
                HStack {
                    Spacer()
                    Button(action: {
                        viewModel.stopSession()
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                            .padding()
                            .background(Circle().fill(Color.white.opacity(0.2)))
                    }
                }
                .padding()

                Spacer()

                // Agent Avatar with Pulse
                ZStack {
                    if viewModel.state == .listening || viewModel.state == .speaking {
                        PulseView()
                    }

                    Circle()
                        .fill(LinearGradient(
                            gradient: Gradient(colors: [.blue, .purple]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 140, height: 140)
                        .overlay(
                            Image(systemName: "mic.fill") // Placeholder for agent avatar
                                .font(.system(size: 60))
                                .foregroundColor(.white)
                        )
                }

                // Status Text
                Text(statusText)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.blue)

                // Transcription
                ScrollView {
                    Text(viewModel.transcription)
                        .font(.system(size: 24, weight: .regular))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding()
                }
                .frame(maxHeight: 150)

                // Waveform
                HStack(spacing: 4) {
                    ForEach(0..<10) { index in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.blue)
                            .frame(width: 4, height: 20 + CGFloat(viewModel.waveformSamples[index] * 50))
                            .animation(.easeInOut(duration: 0.1), value: viewModel.waveformSamples)
                    }
                }
                .frame(height: 80)

                Spacer()

                // Controls
                HStack(spacing: 40) {
                    Button(action: {
                        viewModel.toggleListening()
                    }) {
                        ZStack {
                            Circle()
                                .fill(viewModel.state == .listening ? Color.red : Color.blue)
                                .frame(width: 80, height: 80)

                            Image(systemName: viewModel.state == .listening ? "stop.fill" : "mic.fill")
                                .font(.title)
                                .foregroundColor(.white)
                        }
                    }
                }
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            viewModel.startSession()
        }
        .onDisappear {
            viewModel.stopSession()
        }
    }

    private var statusText: String {
        switch viewModel.state {
        case .idle: return "Tap to speak"
        case .listening: return "Listening..."
        case .processing: return "Thinking..."
        case .speaking: return "Speaking..."
        case .error(let msg): return "Error: \(msg)"
        }
    }
}

struct PulseView: View {
    @State private var animate = false

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.blue.opacity(0.5), lineWidth: 2)
                .frame(width: 140, height: 140)
                .scaleEffect(animate ? 2 : 1)
                .opacity(animate ? 0 : 1)
                .onAppear {
                    withAnimation(Animation.easeOut(duration: 2).repeatForever(autoreverses: false)) {
                        self.animate = true
                    }
                }
        }
    }
}

#Preview {
    VoiceModeView()
}
