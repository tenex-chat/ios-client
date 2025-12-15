//
// MentionAutocompleteView.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import NDKSwiftCore
import NDKSwiftUI
import SwiftUI
import TENEXCore

// MARK: - MentionAutocompleteView

/// Popup view showing filtered agents for @mention autocomplete
public struct MentionAutocompleteView: View {
    // MARK: Lifecycle

    /// Initialize the mention autocomplete view
    /// - Parameters:
    ///   - viewModel: The autocomplete view model
    ///   - ndk: The NDK instance for profile pictures
    ///   - onSelect: Callback when an agent is selected
    public init(
        viewModel: MentionAutocompleteViewModel,
        ndk: NDK,
        onSelect: @escaping (String, String) -> Void
    ) {
        self.viewModel = viewModel
        self.ndk = ndk
        self.onSelect = onSelect
    }

    // MARK: Public

    public var body: some View {
        if self.viewModel.isVisible, !self.viewModel.filteredAgents.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(self.viewModel.filteredAgents.enumerated()), id: \.element.pubkey) { index, agent in
                    self.agentRow(agent, isSelected: index == self.viewModel.selectedIndex)
                        .onTapGesture {
                            if let result = viewModel.selectAgent(at: index) {
                                self.onSelect(result.replacement, result.pubkey)
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
    private let ndk: NDK
    private let onSelect: (String, String) -> Void

    private func agentRow(_ agent: ProjectAgent, isSelected: Bool) -> some View {
        HStack(spacing: 10) {
            NDKUIProfilePicture(ndk: self.ndk, pubkey: agent.pubkey, size: 28)

            // Agent info
            VStack(alignment: .leading, spacing: 2) {
                Text(agent.name)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)

                if let model = agent.model {
                    Text(model)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if agent.isGlobal {
                Text("Global")
                    .font(.caption2.weight(.medium))
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
}
