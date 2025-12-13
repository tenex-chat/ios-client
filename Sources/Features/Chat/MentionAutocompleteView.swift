//
// MentionAutocompleteView.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import SwiftUI
import TENEXCore

// MARK: - MentionAutocompleteView

/// Popup view showing filtered agents for @mention autocomplete
public struct MentionAutocompleteView: View {
    // MARK: Lifecycle

    /// Initialize the mention autocomplete view
    /// - Parameters:
    ///   - viewModel: The autocomplete view model
    ///   - onSelect: Callback when an agent is selected
    public init(
        viewModel: MentionAutocompleteViewModel,
        onSelect: @escaping (String, String) -> Void
    ) {
        self.viewModel = viewModel
        self.onSelect = onSelect
    }

    // MARK: Public

    public var body: some View {
        if viewModel.isVisible, !viewModel.filteredAgents.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(viewModel.filteredAgents.enumerated()), id: \.element.pubkey) { index, agent in
                    agentRow(agent, isSelected: index == viewModel.selectedIndex)
                        .onTapGesture {
                            if let result = viewModel.selectAgent(at: index) {
                                onSelect(result.replacement, result.pubkey)
                            }
                        }
                }
            }
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
            .frame(maxWidth: 280)
        }
    }

    // MARK: Private

    @Bindable private var viewModel: MentionAutocompleteViewModel
    private let onSelect: (String, String) -> Void

    private func agentRow(_ agent: ProjectAgent, isSelected: Bool) -> some View {
        HStack(spacing: 10) {
            // Agent avatar (placeholder - will use NDKUIProfilePicture when NDKSwiftUI bug is fixed)
            agentAvatar(for: agent)

            // Agent info
            VStack(alignment: .leading, spacing: 2) {
                Text(agent.name)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.primary)

                if let model = agent.model {
                    Text(model)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if agent.isGlobal {
                Text("Global")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(.blue.opacity(0.7), in: Capsule())
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isSelected ? Color.blue.opacity(0.15) : Color.clear)
        .contentShape(Rectangle())
    }

    private func agentAvatar(for agent: ProjectAgent) -> some View {
        let initial = agent.name.prefix(1).uppercased()
        return Text(initial)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 28, height: 28)
            .background(Color.blue.gradient, in: Circle())
    }
}
