//
// VODPlaybackView.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation
import SwiftUI
import TENEXCore

// MARK: - VODRecording

/// Represents a recorded call
public struct VODRecording: Identifiable {
    // MARK: Lifecycle

    public init(
        projectID: String,
        agentPubkey: String,
        agentName: String,
        startTime: Date,
        endTime: Date?,
        duration: TimeInterval,
        messages: [CallMessage],
        fileURL: URL,
        id: String = UUID().uuidString
    ) {
        self.id = id
        self.projectID = projectID
        self.agentPubkey = agentPubkey
        self.agentName = agentName
        self.startTime = startTime
        self.endTime = endTime
        self.duration = duration
        self.messages = messages
        self.fileURL = fileURL
    }

    // MARK: Public

    public let id: String
    public let projectID: String
    public let agentPubkey: String
    public let agentName: String
    public let startTime: Date
    public let endTime: Date?
    public let duration: TimeInterval
    public let messages: [CallMessage]
    public let fileURL: URL

    /// Load a VOD recording from a file
    public static func load(from url: URL) throws -> Self {
        let data = try Data(contentsOf: url)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]

        guard let projectID = json["projectID"] as? String,
              let agentPubkey = json["agentPubkey"] as? String,
              let agentName = json["agentName"] as? String,
              let startTimeString = json["startTime"] as? String else {
            throw VODError.invalidFormat
        }

        let formatter = ISO8601DateFormatter()
        guard let startTime = formatter.date(from: startTimeString) else {
            throw VODError.invalidFormat
        }

        let endTime: Date? = {
            if let endTimeString = json["endTime"] as? String {
                return formatter.date(from: endTimeString)
            }
            return nil
        }()

        let duration = json["duration"] as? TimeInterval ?? 0.0

        let messagesData = json["messages"] as? [[String: Any]] ?? []
        let messages: [CallMessage] = messagesData.compactMap { messageData in
            guard let id = messageData["id"] as? String,
                  let senderString = messageData["sender"] as? String,
                  let content = messageData["content"] as? String,
                  let timestampString = messageData["timestamp"] as? String,
                  let timestamp = formatter.date(from: timestampString) else {
                return nil
            }

            let sender: CallParticipant = senderString == "user"
                ? .user
                : .agent(pubkey: agentPubkey, name: agentName, voiceID: nil)

            return CallMessage(
                id: id,
                sender: sender,
                content: content,
                timestamp: timestamp
            )
        }

        return Self(
            projectID: projectID,
            agentPubkey: agentPubkey,
            agentName: agentName,
            startTime: startTime,
            endTime: endTime,
            duration: duration,
            messages: messages,
            fileURL: url
        )
    }
}

// MARK: - VODError

public enum VODError: LocalizedError {
    case invalidFormat
    case fileNotFound

    // MARK: Public

    public var errorDescription: String? {
        switch self {
        case .invalidFormat:
            "Invalid VOD recording format"
        case .fileNotFound:
            "VOD recording file not found"
        }
    }
}

// MARK: - VODPlaybackViewModel

/// View model for VOD playback
@MainActor
@Observable
public final class VODPlaybackViewModel {
    // MARK: Lifecycle

    /// Initialize VOD playback view model
    /// - Parameters:
    ///   - recording: The VOD recording to play
    ///   - audioService: Audio service for TTS playback
    public init(recording: VODRecording, audioService: AudioService) {
        self.recording = recording
        self.audioService = audioService
    }

    // MARK: Public

    /// The VOD recording being played
    public let recording: VODRecording

    /// Current playback position (message index)
    public private(set) var currentMessageIndex = 0

    /// Whether playback is in progress
    public private(set) var isPlaying = false

    /// Playback speed (1.0 = normal speed)
    public var playbackSpeed = 1.0

    /// Error message if playback fails
    public private(set) var error: String?

    /// Current message being played
    public var currentMessage: CallMessage? {
        guard currentMessageIndex < recording.messages.count else {
            return nil
        }
        return recording.messages[currentMessageIndex]
    }

    /// Play the recording from the beginning
    public func play() async {
        guard !isPlaying else {
            return
        }

        isPlaying = true
        error = nil

        // Play each message sequentially
        for (index, message) in recording.messages.enumerated() {
            guard isPlaying else { break }

            currentMessageIndex = index

            // Only speak agent messages
            if case .agent = message.sender {
                do {
                    try await audioService.speak(text: message.content, voiceID: nil)
                } catch {
                    self.error = error.localizedDescription
                    break
                }
            }

            // Delay between messages (based on playback speed)
            if index < recording.messages.count - 1 {
                try? await Task.sleep(nanoseconds: UInt64(1_000_000_000 / playbackSpeed))
            }
        }

        isPlaying = false
        currentMessageIndex = recording.messages.count - 1
    }

    /// Pause playback
    public func pause() {
        isPlaying = false
        audioService.stopSpeaking()
    }

    /// Stop playback and reset
    public func stop() {
        isPlaying = false
        audioService.stopSpeaking()
        currentMessageIndex = 0
    }

    /// Seek to a specific message
    public func seek(to index: Int) {
        guard index >= 0, index < recording.messages.count else {
            return
        }

        audioService.stopSpeaking()
        currentMessageIndex = index
    }

    /// Play a specific message
    public func playMessage(at index: Int) async {
        guard index >= 0, index < recording.messages.count else {
            return
        }

        let message = recording.messages[index]
        currentMessageIndex = index

        do {
            try await audioService.speak(text: message.content, voiceID: nil)
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: Private

    private let audioService: AudioService
}

// MARK: - VODPlaybackView

/// View for playing back recorded calls
public struct VODPlaybackView: View {
    // MARK: Lifecycle

    public init(
        viewModel: VODPlaybackViewModel,
        projectColor: Color = .blue,
        onDismiss: @escaping () -> Void
    ) {
        _viewModel = State(initialValue: viewModel)
        self.projectColor = projectColor
        self.onDismiss = onDismiss
    }

    // MARK: Public

    public var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Recording info
                    recordingInfo
                        .padding()
                        .background(Color.white.opacity(0.05))

                    // Messages
                    messagesView

                    // Playback controls
                    playbackControls
                        .padding()
                        .background(Color.white.opacity(0.05))
                }
            }
            .navigationTitle("Call Recording")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        onDismiss()
                    }
                    .foregroundStyle(projectColor)
                }
            }
            .preferredColorScheme(.dark)
        }
    }

    // MARK: Private

    @State private var viewModel: VODPlaybackViewModel

    private let projectColor: Color
    private let onDismiss: () -> Void

    private var progress: Double {
        guard !viewModel.recording.messages.isEmpty else {
            return 0
        }
        return Double(viewModel.currentMessageIndex + 1) / Double(viewModel.recording.messages.count)
    }

    private var recordingInfo: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.recording.agentName)
                        .font(.headline)
                        .foregroundStyle(.white)

                    Text(formatDate(viewModel.recording.startTime))
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Duration")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))

                    Text(formatDuration(viewModel.recording.duration))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white)
                }
            }

            progressIndicator
        }
    }

    private var progressIndicator: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.white.opacity(0.2))
                    .frame(height: 4)

                Rectangle()
                    .fill(projectColor)
                    .frame(
                        width: geometry.size.width * progress,
                        height: 4
                    )
            }
        }
        .frame(height: 4)
        .clipShape(Capsule())
    }

    private var messagesView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(Array(viewModel.recording.messages.enumerated()), id: \.element.id) { index, message in
                        MessageBubble(
                            message: message,
                            accentColor: projectColor
                        ) {
                            Task {
                                await viewModel.playMessage(at: index)
                            }
                        }
                        .opacity(index <= viewModel.currentMessageIndex ? 1.0 : 0.5)
                        .id(message.id)
                    }
                }
                .padding()
            }
            .onChange(of: viewModel.currentMessageIndex) { _, newValue in
                if newValue < viewModel.recording.messages.count {
                    let message = viewModel.recording.messages[newValue]
                    withAnimation {
                        proxy.scrollTo(message.id, anchor: .center)
                    }
                }
            }
        }
    }

    private var playbackControls: some View {
        VStack(spacing: 16) {
            // Error display
            if let error = viewModel.error {
                errorDisplay(error)
            }

            controlButtons

            // Message counter
            Text("\(viewModel.currentMessageIndex + 1) / \(viewModel.recording.messages.count)")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))
        }
    }

    private var controlButtons: some View {
        HStack(spacing: 32) {
            stopButton
            playPauseButton
            speedControl
        }
    }

    private var stopButton: some View {
        Button {
            viewModel.stop()
        } label: {
            Image(systemName: "stop.fill")
                .font(.system(size: 24))
                .foregroundStyle(.white)
                .frame(width: 50, height: 50)
        }
    }

    private var playPauseButton: some View {
        Button {
            Task {
                if viewModel.isPlaying {
                    viewModel.pause()
                } else {
                    await viewModel.play()
                }
            }
        } label: {
            ZStack {
                Circle()
                    .fill(projectColor)
                    .frame(width: 70, height: 70)

                Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.white)
            }
            .shadow(color: projectColor.opacity(0.5), radius: 10)
        }
    }

    private var speedControl: some View {
        Menu {
            ForEach([0.5, 0.75, 1.0, 1.25, 1.5, 2.0], id: \.self) { speed in
                Button("\(String(format: "%.2f", speed))x") {
                    viewModel.playbackSpeed = speed
                }
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: "speedometer")
                    .font(.system(size: 20))
                Text("\(String(format: "%.2f", viewModel.playbackSpeed))x")
                    .font(.caption2)
            }
            .foregroundStyle(.white)
            .frame(width: 50, height: 50)
        }
    }

    private func errorDisplay(_ error: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
            Text(error)
                .font(.caption)
                .foregroundStyle(.white)
        }
        .padding(8)
        .background(Color.red.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - Preview

#Preview {
    Text("VOD Playback Preview")
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
}
