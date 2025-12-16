//
// FeedTabContent.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import SwiftUI

// MARK: - FeedTabContent

/// Displays activity feed for a project in a compact column layout
///
/// This is a placeholder view that will be implemented in a future version.
/// When implemented, it will provide:
/// - Real-time project activity stream
/// - Event notifications and updates
/// - Filterable activity history
@MainActor
public struct FeedTabContent: View {
    // MARK: Lifecycle

    /// Initialize feed tab content
    /// - Parameters:
    ///   - projectID: The project coordinate string (kind:pubkey:dTag)
    ///   - currentUserPubkey: The current user's pubkey
    public init(projectID: String, currentUserPubkey: String?) {
        self.projectID = projectID
        self.currentUserPubkey = currentUserPubkey
    }

    // MARK: Public

    public var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "list.bullet")
                .font(.largeTitle)
                .foregroundStyle(.secondary)

            Text("Activity Feed")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("Project activity will appear here")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Private

    private let projectID: String
    private let currentUserPubkey: String?
}
