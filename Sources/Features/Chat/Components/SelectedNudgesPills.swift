//
// SelectedNudgesPills.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import SwiftUI
import TENEXCore

// MARK: - SelectedNudgesPills

/// Horizontal scrollable list of selected nudge pills
public struct SelectedNudgesPills: View {
    // MARK: Lifecycle

    public init(
        selectedNudges: [String],
        availableNudges: [Nudge],
        onRemove: @escaping (String) -> Void
    ) {
        self.selectedNudges = selectedNudges
        self.availableNudges = availableNudges
        self.onRemove = onRemove
    }

    // MARK: Public

    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(selectedNudges, id: \.self) { nudgeID in
                    if let nudge = availableNudges.first(where: { $0.id == nudgeID }) {
                        NudgePill(nudge: nudge) {
                            onRemove(nudgeID)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: Private

    private let selectedNudges: [String]
    private let availableNudges: [Nudge]
    private let onRemove: (String) -> Void
}

// MARK: - NudgePill

/// Individual nudge pill with remove button
private struct NudgePill: View {
    let nudge: Nudge
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Text(nudge.title)
                .font(.caption)

            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.blue.opacity(0.1))
        .foregroundStyle(.blue)
        .clipShape(Capsule())
    }
}
