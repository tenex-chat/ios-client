//
// SkillsSelectorSheet.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import SwiftUI
import TENEXCore

// MARK: - SkillsSelectorSheet

/// Sheet for selecting skills (capability enhancements with optional file attachments)
/// Skills are kind:4202 events that provide reusable instruction sets for agents
public struct SkillsSelectorSheet: View {
    // MARK: Lifecycle

    public init(
        selectedSkills: Binding<[String]>,
        availableSkills: [Skill]
    ) {
        _selectedSkills = selectedSkills
        self.availableSkills = availableSkills
    }

    // MARK: Public

    public var body: some View {
        NavigationStack {
            Group {
                if self.availableSkills.isEmpty {
                    self.emptyStateView
                } else {
                    self.skillList
                }
            }
            .navigationTitle("Select Skills")
            #if !os(macOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") {
                            self.dismiss()
                        }
                    }
                }
                .searchable(text: self.$searchText, prompt: "Search skills...")
        }
    }

    // MARK: Private

    @Binding private var selectedSkills: [String]
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private let availableSkills: [Skill]

    private var filteredSkills: [Skill] {
        if self.searchText.isEmpty {
            return self.availableSkills
        }

        let lowercasedSearch = self.searchText.lowercased()
        return self.availableSkills.filter { skill in
            skill.title.lowercased().contains(lowercasedSearch) ||
                (skill.description?.lowercased().contains(lowercasedSearch) ?? false) ||
                skill.hashtags.contains { $0.lowercased().contains(lowercasedSearch) }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "bolt.slash")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("No Skills Available")
                .font(.headline)

            Text("Skills are reusable instruction sets that enhance agent capabilities")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var skillList: some View {
        List {
            if self.filteredSkills.isEmpty {
                self.noSearchResultsView
            } else {
                ForEach(self.filteredSkills) { skill in
                    SkillRow(
                        skill: skill,
                        isSelected: self.selectedSkills.contains(skill.id)
                    ) {
                        self.toggleSkill(skill.id)
                    }
                }
            }
        }
    }

    private var noSearchResultsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)

            Text("No Results")
                .font(.headline)

            Text("No skills match \"\(self.searchText)\"")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }

    private func toggleSkill(_ skillID: String) {
        if self.selectedSkills.contains(skillID) {
            self.selectedSkills.removeAll { $0 == skillID }
        } else {
            self.selectedSkills.append(skillID)
        }
    }
}

// MARK: - SkillRow

/// Row showing a single skill with checkbox
private struct SkillRow: View {
    let skill: Skill
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: self.onToggle) {
            self.rowContent
        }
        .buttonStyle(.plain)
    }

    private var rowContent: some View {
        HStack(alignment: .top, spacing: 12) {
            self.checkboxIcon
            self.skillDetails
            Spacer()
        }
        .contentShape(Rectangle())
    }

    private var checkboxIcon: some View {
        Image(systemName: self.isSelected ? "checkmark.circle.fill" : "circle")
            .font(.title3)
            .foregroundStyle(self.isSelected ? .orange : .secondary)
    }

    private var skillDetails: some View {
        VStack(alignment: .leading, spacing: 4) {
            self.titleRow
            self.descriptionView
            self.hashtagsView
        }
    }

    private var titleRow: some View {
        HStack(spacing: 6) {
            Image(systemName: "bolt.fill")
                .font(.caption)
                .foregroundStyle(.orange)

            Text(self.skill.title)
                .font(.callout.weight(.medium))
                .foregroundStyle(.primary)

            if self.skill.hasFiles {
                Image(systemName: "doc.fill")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var descriptionView: some View {
        if let description = skill.description {
            Text(description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
    }

    @ViewBuilder
    private var hashtagsView: some View {
        if !self.skill.hashtags.isEmpty {
            HStack(spacing: 6) {
                ForEach(self.skill.hashtags.prefix(3), id: \.self) { tag in
                    Text("#\(tag)")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
                if self.skill.hashtags.count > 3 {
                    Text("+\(self.skill.hashtags.count - 3)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.top, 2)
        }
    }
}
