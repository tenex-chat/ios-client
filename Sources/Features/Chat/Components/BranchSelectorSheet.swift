//
// BranchSelectorSheet.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import SwiftUI

// MARK: - BranchSelectorSheet

/// Sheet for selecting a git branch/worktree
public struct BranchSelectorSheet: View {
    // MARK: Lifecycle

    public init(
        selectedBranch: Binding<String?>,
        availableBranches: [String],
        defaultBranch: String?
    ) {
        _selectedBranch = selectedBranch
        self.availableBranches = availableBranches
        self.defaultBranch = defaultBranch
    }

    // MARK: Public

    public var body: some View {
        NavigationStack {
            Group {
                if self.availableBranches.isEmpty {
                    self.emptyStateView
                } else {
                    self.branchList
                }
            }
            .navigationTitle("Select Branch")
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
        }
    }

    // MARK: Private

    @Binding private var selectedBranch: String?
    @Environment(\.dismiss) private var dismiss

    private let availableBranches: [String]
    private let defaultBranch: String?

    /// The branch that should appear selected (explicit selection or default)
    private var displayBranch: String? {
        self.selectedBranch ?? self.defaultBranch
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "arrow.branch")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("No Branches Available")
                .font(.headline)

            Text("No git branches are available for this project")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var branchList: some View {
        List {
            // Default branch section
            if let defaultBranch {
                BranchRow(
                    branch: defaultBranch,
                    isDefault: true,
                    isSelected: self.displayBranch == defaultBranch
                ) {
                    // Selecting the default branch clears the explicit selection
                    self.selectedBranch = nil
                    self.dismiss()
                }
            }

            // Separator if there are other branches
            if self.availableBranches.count > 1 {
                Divider()
            }

            // Other branches
            ForEach(self.availableBranches.filter { $0 != defaultBranch }, id: \.self) { branch in
                BranchRow(
                    branch: branch,
                    isDefault: false,
                    isSelected: self.displayBranch == branch
                ) {
                    self.selectedBranch = branch
                    self.dismiss()
                }
            }
        }
    }
}

// MARK: - BranchRow

/// Row showing a single branch
private struct BranchRow: View {
    let branch: String
    let isDefault: Bool
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: self.onSelect) {
            HStack(spacing: 12) {
                Image(systemName: "arrow.branch")
                    .font(.callout)
                    .foregroundStyle(.green)

                VStack(alignment: .leading, spacing: 2) {
                    Text(self.branch)
                        .font(.callout)
                        .foregroundStyle(.primary)

                    if self.isDefault {
                        Text("Default branch")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if self.isSelected {
                    Image(systemName: "checkmark")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.blue)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
