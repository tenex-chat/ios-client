//
// CallAgentSelectorSheet.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import NDKSwiftCore
import SwiftUI
import TENEXCore

// MARK: - CallAgentSelectorSheet

/// Sheet for selecting an agent during a call
struct CallAgentSelectorSheet: View {
    // MARK: Internal

    let agents: [ProjectAgent]
    let currentAgentPubkey: String
    let availableModels: [String]
    let availableTools: [String]
    let projectReference: String
    let ndk: NDK
    let onSelect: (ProjectAgent) -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationView {
            List {
                ForEach(self.agents) { agent in
                    self.agentRow(agent)
                }
            }
            .navigationTitle("Select Agent")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: self.onCancel)
                }
            }
        }
        .presentationDetents([.medium])
        .sheet(isPresented: self.$showAgentConfig) {
            if let agent = configAgent {
                AgentConfigSheet(
                    isPresented: self.$showAgentConfig,
                    agent: agent,
                    availableModels: self.availableModels,
                    availableTools: self.availableTools,
                    projectReference: self.projectReference,
                    ndk: self.ndk
                )
            }
        }
    }

    // MARK: Private

    @State private var showAgentConfig = false
    @State private var configAgent: ProjectAgent?

    private func agentRow(_ agent: ProjectAgent) -> some View {
        HStack(spacing: 12) {
            self.agentSelectButton(for: agent)
            self.settingsButton(for: agent)
        }
    }

    private func agentSelectButton(for agent: ProjectAgent) -> some View {
        Button {
            self.onSelect(agent)
        } label: {
            self.agentRowContent(for: agent)
        }
        .buttonStyle(.plain)
    }

    private func agentRowContent(for agent: ProjectAgent) -> some View {
        HStack(spacing: 12) {
            self.agentAvatar(for: agent)
            self.agentInfo(for: agent)
            Spacer()
            self.selectionCheckmark(for: agent)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    private func agentAvatar(for agent: ProjectAgent) -> some View {
        Circle()
            .fill(self.colorFor(agent))
            .frame(width: 40, height: 40)
            .overlay {
                Text(self.initialsFor(agent))
                    .font(.headline)
                    .foregroundStyle(.white)
            }
    }

    private func agentInfo(for agent: ProjectAgent) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(agent.name)
                .font(.callout.weight(.medium))
                .foregroundStyle(.primary)
            if let model = agent.model {
                Text(model)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func selectionCheckmark(for agent: ProjectAgent) -> some View {
        if agent.pubkey == self.currentAgentPubkey {
            Image(systemName: "checkmark.circle.fill")
                .font(.title2)
                .foregroundStyle(.blue)
        }
    }

    private func settingsButton(for agent: ProjectAgent) -> some View {
        Button {
            self.configAgent = agent
            self.showAgentConfig = true
        } label: {
            Image(systemName: "gear")
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func colorFor(_ agent: ProjectAgent) -> Color {
        let hash = agent.pubkey.hashValue
        let hue = Double(abs(hash) % 360) / 360.0
        return Color(hue: hue, saturation: 0.6, brightness: 0.7)
    }

    private func initialsFor(_ agent: ProjectAgent) -> String {
        let words = agent.name.split(separator: " ")
        if words.count >= 2 {
            return String(words[0].prefix(1) + words[1].prefix(1)).uppercased()
        } else if let first = words.first {
            return String(first.prefix(2)).uppercased()
        }
        return "?"
    }
}
