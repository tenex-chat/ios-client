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
        availableBranches: [String]
    ) {
        _selectedBranch = selectedBranch
        self.availableBranches = availableBranches
    }

    // MARK: Public

    public var body: some View {
        NavigationStack {
            Group {
                if availableBranches.isEmpty {
                    emptyStateView
                } else {
                    branchList
                }
            }
            .navigationTitle("Select Branch")
            #if !os(macOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
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

    @Binding private var selectedBranch: String?
    @Environment(\.dismiss) private var dismiss

    private let availableBranches: [String]

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
            ForEach(availableBranches, id: \.self) { branch in
                BranchRow(
                    branch: branch,
                    isSelected: selectedBranch == branch
                ) {
                    selectedBranch = branch
                    dismiss()
                }
            }
        }
    }
}

// MARK: - BranchRow

/// Row showing a single branch
private struct BranchRow: View {
    let branch: String
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                Image(systemName: "arrow.branch")
                    .font(.system(size: 16))
                    .foregroundStyle(.green)

                Text(branch)
                    .font(.system(size: 16))
                    .foregroundStyle(.primary)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.blue)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
