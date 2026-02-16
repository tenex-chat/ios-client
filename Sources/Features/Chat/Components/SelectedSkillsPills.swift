//
// SelectedSkillsPills.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import SwiftUI
import TENEXCore

// MARK: - SelectedSkillsPills

/// Horizontal scrollable list of selected skill pills
public struct SelectedSkillsPills: View {
    // MARK: Lifecycle

    public init(
        selectedSkills: [String],
        availableSkills: [Skill],
        onRemove: @escaping (String) -> Void
    ) {
        self.selectedSkills = selectedSkills
        self.availableSkills = availableSkills
        self.onRemove = onRemove
    }

    // MARK: Public

    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(selectedSkills, id: \.self) { skillID in
                    if let skill = availableSkills.first(where: { $0.id == skillID }) {
                        SkillPill(skill: skill) {
                            onRemove(skillID)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: Private

    private let selectedSkills: [String]
    private let availableSkills: [Skill]
    private let onRemove: (String) -> Void
}

// MARK: - SkillPill

/// Individual skill pill with remove button
private struct SkillPill: View {
    let skill: Skill
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "bolt.fill")
                .font(.caption2)
                .foregroundStyle(.orange)

            Text(skill.title)
                .font(.caption)

            // File indicator
            if skill.hasFiles {
                Image(systemName: "doc.fill")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.orange.opacity(0.1))
        .foregroundStyle(.orange)
        .clipShape(Capsule())
    }
}
