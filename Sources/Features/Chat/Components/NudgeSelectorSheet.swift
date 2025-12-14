//
// NudgeSelectorSheet.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import SwiftUI
import TENEXCore

// MARK: - NudgeSelectorSheet

/// Sheet for selecting nudges (system prompt modifiers)
public struct NudgeSelectorSheet: View {
    // MARK: Lifecycle

    public init(
        selectedNudges: Binding<[String]>,
        availableNudges: [Nudge]
    ) {
        _selectedNudges = selectedNudges
        self.availableNudges = availableNudges
    }

    // MARK: Public

    public var body: some View {
        NavigationStack {
            Group {
                if availableNudges.isEmpty {
                    emptyStateView
                } else {
                    nudgeList
                }
            }
            .navigationTitle("Select Nudges")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: Private

    @Binding private var selectedNudges: [String]
    @Environment(\.dismiss) private var dismiss

    private let availableNudges: [Nudge]

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "square.slash")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("No Nudges Available")
                .font(.headline)

            Text("Nudges are system prompt modifiers that customize AI behavior")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var nudgeList: some View {
        List {
            ForEach(availableNudges) { nudge in
                NudgeRow(
                    nudge: nudge,
                    isSelected: selectedNudges.contains(nudge.id)
                ) {
                    toggleNudge(nudge.id)
                }
            }
        }
    }

    private func toggleNudge(_ nudgeID: String) {
        if selectedNudges.contains(nudgeID) {
            selectedNudges.removeAll { $0 == nudgeID }
        } else {
            selectedNudges.append(nudgeID)
        }
    }
}

// MARK: - NudgeRow

/// Row showing a single nudge with checkbox
private struct NudgeRow: View {
    let nudge: Nudge
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(isSelected ? .blue : .secondary)

                VStack(alignment: .leading, spacing: 4) {
                    Text(nudge.title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.primary)

                    if let description = nudge.description {
                        Text(description)
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }

                    if !nudge.hashtags.isEmpty {
                        HStack(spacing: 6) {
                            ForEach(nudge.hashtags, id: \.self) { tag in
                                Text("#\(tag)")
                                    .font(.caption2)
                                    .foregroundStyle(.blue)
                            }
                        }
                        .padding(.top, 2)
                    }
                }

                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
