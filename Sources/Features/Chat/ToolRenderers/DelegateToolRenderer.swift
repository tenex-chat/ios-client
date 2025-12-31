//
// DelegateToolRenderer.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import NDKSwiftCore
import SwiftUI
import TENEXCore

// MARK: - DelegateToolRenderer

/// Renderer for delegate tool calls
public struct DelegateToolRenderer: View {
    // MARK: Lifecycle

    public init(ndk: NDK?, delegations: [Delegation], conversationIDs: [String]) {
        self.ndk = ndk
        self.delegations = delegations
        self.conversationIDs = conversationIDs
    }

    // MARK: Public

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(delegationsWithIDs, id: \.conversationID) { item in
                if let ndk, let conversationID = item.conversationID {
                    DelegationPreview(
                        ndk: ndk,
                        conversationID: conversationID,
                        recipientName: item.delegation.recipient,
                        prompt: item.delegation.prompt
                    )
                } else {
                    fallbackView(for: item.delegation)
                }
            }
        }
    }

    // MARK: Private

    private let ndk: NDK?
    private let delegations: [Delegation]
    private let conversationIDs: [String]

    private var delegationsWithIDs: [DelegationWithID] {
        delegations.enumerated().map { index, delegation in
            DelegationWithID(
                delegation: delegation,
                conversationID: conversationIDs[safe: index]
            )
        }
    }

    @ViewBuilder
    private func fallbackView(for delegation: Delegation) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "person.2")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("Delegating to ")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                + Text(delegation.recipient ?? "unknown")
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - DelegationWithID

private struct DelegationWithID: Identifiable {
    let delegation: Delegation
    let conversationID: String?

    var id: String { conversationID ?? UUID().uuidString }
}
