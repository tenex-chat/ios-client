//
// CallAgentSelectorSheet.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import SwiftUI
import TENEXCore

// MARK: - CallAgentSelectorSheet

/// Sheet for selecting an agent during a call
struct CallAgentSelectorSheet: View {
    // MARK: Internal

    let agents: [ProjectAgent]
    let currentAgentPubkey: String
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
    }

    // MARK: Private

    private func agentRow(_ agent: ProjectAgent) -> some View {
        Button {
            self.onSelect(agent)
        } label: {
            HStack(spacing: 12) {
                Circle()
                    .fill(self.colorFor(agent))
                    .frame(width: 40, height: 40)
                    .overlay {
                        Text(self.initialsFor(agent))
                            .font(.headline)
                            .foregroundStyle(.white)
                    }

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

                Spacer()

                if agent.pubkey == self.currentAgentPubkey {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.blue)
                }
            }
            .padding(.vertical, 4)
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
