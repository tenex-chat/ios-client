//
// TTSCache.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation
import Observation
import OSLog

// MARK: - TTSCache

/// Caches TTS audio files locally for replay capability
@MainActor
@Observable
public final class TTSCache {
    // MARK: Lifecycle

    /// Initialize TTS cache
    public init() {
        self.ensureDirectory()
        self.loadManifest()
    }

    // MARK: Public

    /// Cached audio metadata
    public struct CachedAudio: Codable, Identifiable, Sendable {
        public let id: UUID
        public let messageID: String
        public let text: String
        public let voiceID: String
        public let agentPubkey: String
        public let timestamp: Date
        public let filename: String

        public var fileURL: URL {
            TTSCache.cacheDirectory.appendingPathComponent(self.filename)
        }
    }

    /// Shared singleton instance
    public static let shared = TTSCache()

    /// All cached audio entries
    public var entries: [CachedAudio] {
        self.manifest
    }

    /// Save audio data to cache
    /// - Parameters:
    ///   - audioData: The audio data to cache
    ///   - messageID: The message ID this audio is for
    ///   - text: The text that was synthesized
    ///   - voiceID: The voice ID used for synthesis
    ///   - agentPubkey: The agent's pubkey
    /// - Returns: The cached audio entry
    @discardableResult
    public func save(
        audioData: Data,
        messageID: String,
        text: String,
        voiceID: String,
        agentPubkey: String
    ) -> CachedAudio {
        let cached = CachedAudio(
            id: UUID(),
            messageID: messageID,
            text: text,
            voiceID: voiceID,
            agentPubkey: agentPubkey,
            timestamp: Date(),
            filename: "\(messageID).mp3"
        )

        do {
            try audioData.write(to: cached.fileURL)
            self.manifest.append(cached)
            self.saveManifest()
            self.logger.info("Cached TTS audio for message: \(messageID)")
        } catch {
            self.logger.error("Failed to cache TTS audio: \(error.localizedDescription)")
        }

        return cached
    }

    /// Load audio data for a cached entry
    /// - Parameter cached: The cached audio entry
    /// - Returns: The audio data, or nil if not found
    public func load(cached: CachedAudio) -> Data? {
        try? Data(contentsOf: cached.fileURL)
    }

    /// Get cached audio data for a specific message ID
    /// - Parameter messageID: The message ID to look up
    /// - Returns: The audio data, or nil if not cached
    public func audioFor(messageID: String) -> Data? {
        guard let cached = manifest.first(where: { $0.messageID == messageID }) else {
            return nil
        }
        return self.load(cached: cached)
    }

    /// Check if audio is cached for a message
    /// - Parameter messageID: The message ID to check
    /// - Returns: True if cached, false otherwise
    public func hasCached(messageID: String) -> Bool {
        self.manifest.contains { $0.messageID == messageID }
    }

    /// Delete a cached entry
    /// - Parameter cached: The entry to delete
    public func delete(cached: CachedAudio) {
        try? FileManager.default.removeItem(at: cached.fileURL)
        self.manifest.removeAll { $0.id == cached.id }
        self.saveManifest()
    }

    /// Clear all cached audio
    public func clearAll() {
        for cached in self.manifest {
            try? FileManager.default.removeItem(at: cached.fileURL)
        }
        self.manifest.removeAll()
        self.saveManifest()
    }

    // MARK: Private

    /// nonisolated to allow access from Sendable CachedAudio struct
    private nonisolated static var cacheDirectory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("TTSCache", isDirectory: true)
    }

    private nonisolated static var manifestURL: URL {
        cacheDirectory.appendingPathComponent("manifest.json")
    }

    private var manifest: [CachedAudio] = []
    private let logger = Logger(subsystem: "com.tenex.ios", category: "TTSCache")

    private func ensureDirectory() {
        let dir = Self.cacheDirectory
        if !FileManager.default.fileExists(atPath: dir.path) {
            do {
                try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            } catch {
                self.logger.error("Failed to create TTS cache directory: \(error.localizedDescription)")
            }
        }
    }

    private func loadManifest() {
        guard let data = try? Data(contentsOf: Self.manifestURL),
              let loaded = try? JSONDecoder().decode([CachedAudio].self, from: data)
        else {
            return
        }
        self.manifest = loaded
        self.logger.info("Loaded TTS cache manifest with \(loaded.count) entries")
    }

    private func saveManifest() {
        do {
            let data = try JSONEncoder().encode(self.manifest)
            try data.write(to: Self.manifestURL)
        } catch {
            self.logger.error("Failed to save TTS cache manifest: \(error.localizedDescription)")
        }
    }
}
