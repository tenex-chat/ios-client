//
// ActiveAgentsView.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import NDKSwiftCore
import SwiftUI
import TENEXCore

// MARK: - ActiveAgentsView

/// Displays active agents working on a conversation with stop controls
///
/// Shows agent avatars for agents currently processing the conversation.
/// Tapping an avatar stops that specific agent. A stop-all button is also provided.
public struct ActiveAgentsView: View {
    // MARK: Lifecycle

    /// Initialize the active agents view
    /// - Parameters:
    ///   - eventId: The event/conversation ID to show active agents for
    ///   - projectReference: The project reference for stop commands
    ///   - onlineAgents: List of online agents in the project (for avatar/name display)
    public init(
        eventId: String,
        projectReference: String,
        onlineAgents: [ProjectAgent]
    ) {
        self.eventId = eventId
        self.projectReference = projectReference
        self.onlineAgents = onlineAgents
    }

    // MARK: Public

    public var body: some View {
        if !self.activeAgents.isEmpty {
            HStack(spacing: 8) {
                ForEach(self.activeAgents, id: \.pubkey) { agent in
                    self.agentButton(agent)
                }
                self.stopAllButton
            }
        }
    }

    // MARK: Private

    @Environment(\.ndk) private var ndk
    @Environment(DataStore.self) private var dataStore

    private let eventId: String
    private let projectReference: String
    private let onlineAgents: [ProjectAgent]

    /// Get active agent pubkeys for this event from DataStore
    private var activeAgentPubkeys: Set<String> {
        self.dataStore.activeOperations[self.eventId] ?? []
    }

    /// Filter online agents to only those currently active
    private var activeAgents: [ProjectAgent] {
        self.onlineAgents.filter { self.activeAgentPubkeys.contains($0.pubkey) }
    }

    @ViewBuilder
    private func agentButton(_ agent: ProjectAgent) -> some View {
        Button {
            Task { await self.stopAgent(agent.pubkey) }
        } label: {
            ZStack {
                // Agent avatar circle
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 32, height: 32)
                    .overlay {
                        Text(self.agentInitial(agent))
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.blue)
                    }

                // X overlay for stop indication
                Circle()
                    .fill(Color.red.opacity(0.8))
                    .frame(width: 32, height: 32)
                    .overlay {
                        Image(systemName: "xmark")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                    }
                    .opacity(0)
                    .animation(.easeInOut(duration: 0.15), value: self.activeAgentPubkeys)
            }
        }
        .buttonStyle(.plain)
        .help("Stop \(agent.name)")
    }

    private var stopAllButton: some View {
        Button {
            Task { await self.stopAgent(nil) }
        } label: {
            Image(systemName: "stop.circle.fill")
                .font(.title2)
                .foregroundStyle(.red.opacity(0.7))
        }
        .buttonStyle(.plain)
        .help("Stop all agents")
    }

    private func agentInitial(_ agent: ProjectAgent) -> String {
        String(agent.name.prefix(1)).uppercased()
    }

    private func stopAgent(_ pubkey: String?) async {
        guard let ndk else {
            return
        }
        // Stop commands are best-effort - silently ignore errors
        try? await MessagePublisher().publishStopCommand(
            ndk: ndk,
            projectRef: self.projectReference,
            eventId: self.eventId,
            agentPubkey: pubkey
        )
    }
}
