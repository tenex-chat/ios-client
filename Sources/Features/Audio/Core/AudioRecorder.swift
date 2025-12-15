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

    // MARK: Internal

    private(set) var isRecording = false
    private(set) var audioLevel = 0.0 // 0.0 to 1.0
    private(set) var recordingDuration: TimeInterval = 0.0

    /// Request microphone permission
    func requestPermission() async -> Bool {
        #if os(macOS)
            return true // macOS handles permissions differently
        #else
            await withCheckedContinuation { continuation in
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
        #endif
    }

    /// Start recording audio
    /// - Returns: URL where recording will be saved
    @discardableResult
    func startRecording() async throws -> URL {
        // swiftlint:disable:next no_print_statements
        print("[AudioRecorder] startRecording called")

        #if !os(macOS)
            try await self.checkPermissionAndConfigureSession()
        #endif

        // Create recording file URL
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "recording_\(UUID().uuidString).wav"
        let fileURL = tempDir.appendingPathComponent(fileName)
        self.currentRecordingURL = fileURL
        // swiftlint:disable:next no_print_statements
        print("[AudioRecorder] Recording to: \(fileURL.path)")

        // Create audio recorder
        do {
            self.audioRecorder = try AVAudioRecorder(url: fileURL, settings: self.audioSettings)
            self.audioRecorder?.isMeteringEnabled = true
            self.audioRecorder?.prepareToRecord()

            // swiftlint:disable:next no_print_statements
            print("[AudioRecorder] Starting record()...")
            guard self.audioRecorder?.record() == true else {
                // swiftlint:disable:next no_print_statements
                print("[AudioRecorder] record() returned false")
                throw AudioError.recordingFailed(NSError(
                    domain: "AudioRecorder",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Failed to start recording"]
                ))
            }

            // swiftlint:disable:next no_print_statements
            print("[AudioRecorder] Recording started successfully!")
            self.isRecording = true
            self.startMetering()

            return fileURL
        } catch {
            // swiftlint:disable:next no_print_statements
            print("[AudioRecorder] Error: \(error)")
            throw AudioError.recordingFailed(error)
        }
    }

    /// Stop recording and return the audio file URL
    /// - Returns: URL of recorded audio file
    func stopRecording() async throws -> URL {
        guard self.isRecording, let audioRecorder else {
            throw AudioError.recordingFailed(NSError(
                domain: "AudioRecorder",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Not currently recording"]
            ))
        }

        // Stop metering
        self.stopMetering()

        // Stop recording
        audioRecorder.stop()
        self.audioRecorder = nil
        self.isRecording = false

        // Reset level
        self.audioLevel = 0.0
        self.recordingDuration = 0.0

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
        guard self.isRecording else {
            return
        }

        self.stopMetering()
        self.audioRecorder?.stop()
        self.audioRecorder = nil
        self.isRecording = false
        self.audioLevel = 0.0
        self.recordingDuration = 0.0

        // Delete recording file
        if let url = currentRecordingURL {
            try? FileManager.default.removeItem(at: url)
        }
        self.currentRecordingURL = nil
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

    #if !os(macOS)
        private func checkPermissionAndConfigureSession() async throws {
            let permission = AVAudioSession.sharedInstance().recordPermission
            // swiftlint:disable:next no_print_statements
            print("[AudioRecorder] Current permission: \(permission.rawValue)")
            if permission == .undetermined {
                // swiftlint:disable:next no_print_statements
                print("[AudioRecorder] Requesting permission...")
                let granted = await requestPermission()
                if !granted {
                    // swiftlint:disable:next no_print_statements
                    print("[AudioRecorder] Permission denied")
                    throw AudioError.permissionDenied
                }
                // swiftlint:disable:next no_print_statements
                print("[AudioRecorder] Permission granted")
            } else if permission != .granted {
                // swiftlint:disable:next no_print_statements
                print("[AudioRecorder] Permission not granted: \(permission.rawValue)")
                throw AudioError.permissionDenied
            }

            let session = AVAudioSession.sharedInstance()
            do {
                // swiftlint:disable:next no_print_statements
                print("[AudioRecorder] Setting audio session category...")
                try session.setCategory(.playAndRecord, mode: .default)
                try session.setActive(true)
                // swiftlint:disable:next no_print_statements
                print("[AudioRecorder] Audio session configured")
            } catch {
                // swiftlint:disable:next no_print_statements
                print("[AudioRecorder] Audio session error: \(error)")
                throw AudioError.recordingFailed(error)
            }
        }
    #endif

    // MARK: - Metering

    private func startMetering() {
        self.meteringTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateMetering()
            }
        }
    }

    private func stopMetering() {
        self.meteringTimer?.invalidate()
        self.meteringTimer = nil
    }

    private func updateMetering() {
        guard let audioRecorder, audioRecorder.isRecording else {
            self.audioLevel = 0.0
            return
        }

        audioRecorder.updateMeters()

        // Get average power in dB (-160 to 0)
        let averagePower = audioRecorder.averagePower(forChannel: 0)

        // Convert dB to linear scale (0.0 to 1.0)
        // -160 dB = 0.0, 0 dB = 1.0
        let minDb: Float = -60.0 // Treat anything below -60dB as silence
        let normalizedPower = max(0.0, min(1.0, (averagePower - minDb) / (0 - minDb)))

        self.audioLevel = Double(normalizedPower)
        self.recordingDuration = audioRecorder.currentTime
    }
}
