//
// AudioRecorder.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import AVFoundation
import Foundation
import Observation

/// Manages audio recording with real-time level monitoring
@MainActor
@Observable
final class AudioRecorder {
    // MARK: Lifecycle

    init() {}

    // MARK: - Cleanup

    deinit {
        Task { @MainActor in
            await cancelRecording()
        }
    }

    // MARK: Internal

    private(set) var isRecording = false
    private(set) var audioLevel = 0.0 // 0.0 to 1.0
    private(set) var recordingDuration: TimeInterval = 0.0

    /// Request microphone permission
    func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    /// Start recording audio
    /// - Returns: URL where recording will be saved
    @discardableResult
    func startRecording() async throws -> URL {
        // Check permission
        let permission = AVAudioSession.sharedInstance().recordPermission
        guard permission == .granted else {
            if permission == .undetermined {
                let granted = await requestPermission()
                guard granted else {
                    throw AudioError.permissionDenied
                }
            } else {
                throw AudioError.permissionDenied
            }
        }

        // Configure audio session
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.record, mode: .default)
            try session.setActive(true)
        } catch {
            throw AudioError.recordingFailed(error)
        }

        // Create recording file URL
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "recording_\(UUID().uuidString).wav"
        let fileURL = tempDir.appendingPathComponent(fileName)
        currentRecordingURL = fileURL

        // Create audio recorder
        do {
            audioRecorder = try AVAudioRecorder(url: fileURL, settings: audioSettings)
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.prepareToRecord()

            guard audioRecorder?.record() == true else {
                throw AudioError.recordingFailed(NSError(
                    domain: "AudioRecorder",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Failed to start recording"]
                ))
            }

            isRecording = true

            // Start metering timer
            startMetering()

            return fileURL
        } catch {
            throw AudioError.recordingFailed(error)
        }
    }

    /// Stop recording and return the audio file URL
    /// - Returns: URL of recorded audio file
    func stopRecording() async throws -> URL {
        guard isRecording, let audioRecorder else {
            throw AudioError.recordingFailed(NSError(
                domain: "AudioRecorder",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Not currently recording"]
            ))
        }

        // Stop metering
        stopMetering()

        // Stop recording
        audioRecorder.stop()
        self.audioRecorder = nil
        isRecording = false

        // Reset level
        audioLevel = 0.0
        recordingDuration = 0.0

        guard let url = currentRecordingURL else {
            throw AudioError.recordingFailed(NSError(
                domain: "AudioRecorder",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Recording URL not found"]
            ))
        }

        // Verify file exists
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw AudioError.recordingFailed(NSError(
                domain: "AudioRecorder",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Recording file not found"]
            ))
        }

        return url
    }

    /// Cancel recording and delete the file
    func cancelRecording() async {
        guard isRecording else {
            return
        }

        stopMetering()
        audioRecorder?.stop()
        audioRecorder = nil
        isRecording = false
        audioLevel = 0.0
        recordingDuration = 0.0

        // Delete recording file
        if let url = currentRecordingURL {
            try? FileManager.default.removeItem(at: url)
        }
        currentRecordingURL = nil
    }

    // MARK: Private

    private var audioRecorder: AVAudioRecorder?
    private var meteringTimer: Timer?
    private var currentRecordingURL: URL?

    /// Audio format settings optimized for speech
    private let audioSettings: [String: Any] = [
        AVFormatIDKey: Int(kAudioFormatLinearPCM),
        AVSampleRateKey: 16_000.0, // 16kHz for speech
        AVNumberOfChannelsKey: 1, // Mono
        AVLinearPCMBitDepthKey: 16,
        AVLinearPCMIsFloatKey: false,
        AVLinearPCMIsBigEndianKey: false,
    ]

    // MARK: - Metering

    private func startMetering() {
        meteringTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateMetering()
            }
        }
    }

    private func stopMetering() {
        meteringTimer?.invalidate()
        meteringTimer = nil
    }

    private func updateMetering() {
        guard let audioRecorder, audioRecorder.isRecording else {
            audioLevel = 0.0
            return
        }

        audioRecorder.updateMeters()

        // Get average power in dB (-160 to 0)
        let averagePower = audioRecorder.averagePower(forChannel: 0)

        // Convert dB to linear scale (0.0 to 1.0)
        // -160 dB = 0.0, 0 dB = 1.0
        let minDb: Float = -60.0 // Treat anything below -60dB as silence
        let normalizedPower = max(0.0, min(1.0, (averagePower - minDb) / (0 - minDb)))

        audioLevel = Double(normalizedPower)
        recordingDuration = audioRecorder.currentTime
    }
}
