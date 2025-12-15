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
                sender: sender,
                content: content,
                id: id,
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
        guard self.currentMessageIndex < self.recording.messages.count else {
            return nil
        }
        return self.recording.messages[self.currentMessageIndex]
    }

    /// Play the recording from the beginning
    public func play() async {
        guard !self.isPlaying else {
            return
        }

        self.isPlaying = true
        self.error = nil

        // Play each message sequentially
        for (index, message) in self.recording.messages.enumerated() {
            guard self.isPlaying else { break }

            self.currentMessageIndex = index

            // Only speak agent messages
            if case .agent = message.sender {
                do {
                    try await self.audioService.speak(text: message.content, voiceID: nil)
                } catch {
                    self.error = error.localizedDescription
                    break
                }
            }

            // Delay between messages (based on playback speed)
            if index < self.recording.messages.count - 1 {
                try? await Task.sleep(nanoseconds: UInt64(1_000_000_000 / self.playbackSpeed))
            }
        }

        self.isPlaying = false
        self.currentMessageIndex = self.recording.messages.count - 1
    }

    /// Pause playback
    public func pause() {
        self.isPlaying = false
        self.audioService.stopSpeaking()
    }

    /// Stop playback and reset
    public func stop() {
        self.isPlaying = false
        self.audioService.stopSpeaking()
        self.currentMessageIndex = 0
    }

    /// Seek to a specific message
    public func seek(to index: Int) {
        guard index >= 0, index < self.recording.messages.count else {
            return
        }

        self.audioService.stopSpeaking()
        self.currentMessageIndex = index
    }

    /// Play a specific message
    public func playMessage(at index: Int) async {
        guard index >= 0, index < self.recording.messages.count else {
            return
        }

        let message = self.recording.messages[index]
        self.currentMessageIndex = index

        do {
            try await self.audioService.speak(text: message.content, voiceID: nil)
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
                    self.recordingInfo
                        .padding()
                        .background(Color.white.opacity(0.05))

                    // Messages
                    self.messagesView

                    // Playback controls
                    self.playbackControls
                        .padding()
                        .background(Color.white.opacity(0.05))
                }
            }
            .navigationTitle("Call Recording")
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
                .toolbar {
                    ToolbarItem(placement: .automatic) {
                        Button("Done") {
                            self.onDismiss()
                        }
                        .foregroundStyle(self.projectColor)
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
        guard !self.viewModel.recording.messages.isEmpty else {
            return 0
        }
        return Double(self.viewModel.currentMessageIndex + 1) / Double(self.viewModel.recording.messages.count)
    }

    private var recordingInfo: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(self.viewModel.recording.agentName)
                        .font(.headline)
                        .foregroundStyle(.white)

                    Text(self.formatDate(self.viewModel.recording.startTime))
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Duration")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))

                    Text(self.formatDuration(self.viewModel.recording.duration))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white)
                }
            }

            self.progressIndicator
        }
    }

    private var progressIndicator: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.white.opacity(0.2))
                    .frame(height: 4)

                Rectangle()
                    .fill(self.projectColor)
                    .frame(
                        width: geometry.size.width * self.progress,
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
                    ForEach(Array(self.viewModel.recording.messages.enumerated()), id: \.element.id) { index, message in
                        MessageBubble(
                            message: message,
                            accentColor: self.projectColor
                        ) {
                            Task {
                                await self.viewModel.playMessage(at: index)
                            }
                        }
                        .opacity(index <= self.viewModel.currentMessageIndex ? 1.0 : 0.5)
                        .id(message.id)
                    }
                }
                .padding()
            }
            .onChange(of: self.viewModel.currentMessageIndex) { _, newValue in
                if newValue < self.viewModel.recording.messages.count {
                    let message = self.viewModel.recording.messages[newValue]
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
                self.errorDisplay(error)
            }

            self.controlButtons

            // Message counter
            Text("\(self.viewModel.currentMessageIndex + 1) / \(self.viewModel.recording.messages.count)")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))
        }
    }

    private var controlButtons: some View {
        HStack(spacing: 32) {
            self.stopButton
            self.playPauseButton
            self.speedControl
        }
    }

    private var stopButton: some View {
        Button {
            self.viewModel.stop()
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
                if self.viewModel.isPlaying {
                    self.viewModel.pause()
                } else {
                    await self.viewModel.play()
                }
            }
        } label: {
            ZStack {
                Circle()
                    .fill(self.projectColor)
                    .frame(width: 70, height: 70)

                Image(systemName: self.viewModel.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.white)
            }
            .shadow(color: self.projectColor.opacity(0.5), radius: 10)
        }
    }

    private var speedControl: some View {
        Menu {
            ForEach([0.5, 0.75, 1.0, 1.25, 1.5, 2.0], id: \.self) { speed in
                Button("\(String(format: "%.2f", speed))x") {
                    self.viewModel.playbackSpeed = speed
                }
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: "speedometer")
                    .font(.system(size: 20))
                Text("\(String(format: "%.2f", self.viewModel.playbackSpeed))x")
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
