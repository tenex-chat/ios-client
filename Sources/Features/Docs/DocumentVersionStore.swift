//
// DocumentVersionStore.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation
import NDKSwiftCore
import Observation
import TENEXCore

// MARK: - DocumentVersionStore

/// Manages version history for a document
/// Fetches all versions of a document by d-tag and author
@MainActor
@Observable
public final class DocumentVersionStore {
    // MARK: Lifecycle

    /// Initialize the version store
    /// - Parameters:
    ///   - ndk: The NDK instance
    ///   - document: The document to fetch versions for
    public init(ndk: NDK, document: Document) {
        self.ndk = ndk
        self.dTag = document.dTag
        self.pubkey = document.pubkey
        self.currentDocument = document
    }

    // MARK: Public

    /// All versions of the document, sorted by creation date (newest first)
    public private(set) var versions: [Document] = []

    /// Whether versions are currently loading
    public private(set) var isLoading = false

    /// The currently selected version for comparison
    public var selectedVersionForDiff: Document?

    /// The current/latest version of the document
    public let currentDocument: Document

    /// Number of versions available
    public var versionCount: Int { versions.count }

    /// Whether there are multiple versions to compare
    public var hasMultipleVersions: Bool { versions.count > 1 }

    /// Previous versions (all except the current one)
    public var previousVersions: [Document] {
        guard versions.count > 1 else {
            return []
        }
        return Array(versions.dropFirst())
    }

    /// Subscribe to all versions of the document
    public func subscribe() async {
        guard !dTag.isEmpty else {
            return
        }

        isLoading = true
        defer { isLoading = false }

        let filter = Document.versionFilter(dTag: dTag, pubkey: pubkey)
        let subscription = ndk.subscribe(filter: filter)

        var versionsByID: [String: Document] = [:]

        for await events in subscription.events {
            for event in events {
                guard let document = Document.from(event: event) else {
                    continue
                }

                versionsByID[document.id] = document
            }
            versions = versionsByID.values
                .sorted { $0.createdAt > $1.createdAt }
        }
    }

    /// Fetch versions once (non-streaming)
    public func fetchVersions() async {
        guard !dTag.isEmpty else {
            return
        }

        isLoading = true
        defer { isLoading = false }

        let filter = Document.versionFilter(dTag: dTag, pubkey: pubkey)
        let subscription = ndk.subscribe(filter: filter)

        var fetchedVersions: [Document] = []
        let timeout = Task {
            try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 second timeout
        }

        for await events in subscription.events {
            if Task.isCancelled || timeout.isCancelled {
                break
            }

            for event in events {
                if let document = Document.from(event: event) {
                    fetchedVersions.append(document)
                }
            }

            // Stop if we have enough versions or timeout
            if fetchedVersions.count >= 50 {
                break
            }
        }

        timeout.cancel()
        versions = fetchedVersions.sorted { $0.createdAt > $1.createdAt }
    }

    /// Format the relative time between two versions
    /// - Parameter version: The version to compare with current
    /// - Returns: A human-readable time difference string
    public func timeSinceVersion(_ version: Document) -> String {
        let interval = currentDocument.createdAt.timeIntervalSince(version.createdAt)
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(fromTimeInterval: -interval)
    }

    // MARK: Private

    private let ndk: NDK
    private let dTag: String
    private let pubkey: String
}
