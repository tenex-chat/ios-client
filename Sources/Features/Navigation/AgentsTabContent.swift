//
// AgentsTabContent.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import SwiftUI

// MARK: - AgentsTabContent

/// Displays agents for a project in a compact column layout
///
/// This is a placeholder view that will be implemented in a future version.
/// When implemented, it will provide:
/// - List of agents associated with the project
/// - Agent status and activity monitoring
/// - Agent configuration and management
@MainActor
public struct AgentsTabContent: View {
    // MARK: Lifecycle

    /// Initialize agents tab content
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
            Image(systemName: "person.2")
                .font(.largeTitle)
                .foregroundStyle(.secondary)

            Text("Agents")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("Project agents will appear here")
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
