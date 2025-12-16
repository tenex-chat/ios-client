//
// DocsTabContent.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import SwiftUI

// MARK: - DocsTabContent

/// Displays documentation for a project in a compact column layout
///
/// This is a placeholder view that will be implemented in a future version.
/// When implemented, it will provide:
/// - Project documentation and knowledge base
/// - Document search and browsing
/// - Collaborative document editing
@MainActor
public struct DocsTabContent: View {
    // MARK: Lifecycle

    /// Initialize docs tab content
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
            Image(systemName: "doc.text")
                .font(.largeTitle)
                .foregroundStyle(.secondary)

            Text("Documentation")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("Project documentation will appear here")
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
