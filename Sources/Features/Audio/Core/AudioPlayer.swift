//
// AudioPlayer.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import AVFoundation
import Foundation
import Observation

// MARK: - AudioPlayer

/// Manages audio playback with progress tracking
@MainActor
@Observable
final class AudioPlayer: NSObject {
    // MARK: Lifecycle

    override init() {
        super.init()
    }

    // Note: cleanup handled by stop() called by AudioService

    // MARK: Internal

    private(set) var isPlaying = false
    private(set) var playbackProgress = 0.0 // 0.0 to 1.0

    /// Play audio from data
    /// - Parameter audioData: Audio data to play
    func play(audioData: Data) async throws {
        #if os(iOS)
            /// Configure audio session for playback
            let session = AVAudioSession.sharedInstance()
            do {
                try session.setCategory(.playAndRecord, mode: .default)
                try session.setActive(true)
            } catch {
                throw AudioError.playbackFailed(error)
            }
        #endif

        // Create audio player
        do {
            self.audioPlayer = try AVAudioPlayer(data: audioData)
            self.audioPlayer?.delegate = self
            self.audioPlayer?.prepareToPlay()

            guard self.audioPlayer?.play() == true else {
                throw AudioError.playbackFailed(NSError(
                    domain: "AudioPlayer",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Failed to start playback"]
                ))
            }

            self.isPlaying = true
            self.startProgressTracking()

            // Wait for completion
            await withCheckedContinuation { continuation in
                self.completionContinuation = continuation
            }
        } catch {
            throw AudioError.playbackFailed(error)
        }
    }

    /// Play audio from URL
    /// - Parameter url: URL of audio file
    func play(url: URL) async throws {
        #if os(iOS)
            /// Configure audio session for playback
            let session = AVAudioSession.sharedInstance()
            do {
                try session.setCategory(.playAndRecord, mode: .default)
                try session.setActive(true)
            } catch {
                throw AudioError.playbackFailed(error)
            }
        #endif

        // Create audio player
        do {
            self.audioPlayer = try AVAudioPlayer(contentsOf: url)
            self.audioPlayer?.delegate = self
            self.audioPlayer?.prepareToPlay()

            guard self.audioPlayer?.play() == true else {
                throw AudioError.playbackFailed(NSError(
                    domain: "AudioPlayer",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Failed to start playback"]
                ))
            }

            self.isPlaying = true
            self.startProgressTracking()

            // Wait for completion
            await withCheckedContinuation { continuation in
                self.completionContinuation = continuation
            }
        } catch {
            throw AudioError.playbackFailed(error)
        }
    }

    /// Pause playback
    func pause() {
        self.audioPlayer?.pause()
        self.isPlaying = false
        self.stopProgressTracking()
    }

    /// Stop playback
    func stop() {
        self.stopProgressTracking()
        self.audioPlayer?.stop()
        self.audioPlayer = nil
        self.isPlaying = false
        self.playbackProgress = 0.0

        // Resume continuation if waiting
        self.completionContinuation?.resume()
        self.completionContinuation = nil
    }

    // MARK: Private

    private var audioPlayer: AVAudioPlayer?
    private var progressTimer: Timer?
    private var completionContinuation: CheckedContinuation<Void, Never>?

    // MARK: - Progress Tracking

    private func startProgressTracking() {
        self.progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateProgress()
            }
        }
    }

    private func stopProgressTracking() {
        self.progressTimer?.invalidate()
        self.progressTimer = nil
    }

    private func updateProgress() {
        guard let audioPlayer, audioPlayer.isPlaying else {
            self.playbackProgress = 0.0
            return
        }

        let duration = audioPlayer.duration
        guard duration > 0 else {
            self.playbackProgress = 0.0
            return
        }

        self.playbackProgress = audioPlayer.currentTime / duration
    }
}

// MARK: AVAudioPlayerDelegate

extension AudioPlayer: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_: AVAudioPlayer, successfully _: Bool) {
        Task { @MainActor in
            self.stopProgressTracking()
            self.isPlaying = false
            self.playbackProgress = 1.0
            self.audioPlayer = nil

            // Resume continuation
            self.completionContinuation?.resume()
            self.completionContinuation = nil
        }
    }

    nonisolated func audioPlayerDecodeErrorDidOccur(_: AVAudioPlayer, error _: Error?) {
        Task { @MainActor in
            self.stopProgressTracking()
            self.isPlaying = false
            self.audioPlayer = nil

            // Resume continuation
            self.completionContinuation?.resume()
            self.completionContinuation = nil
        }
    }
}
