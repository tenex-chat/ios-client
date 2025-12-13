//
// DangerZoneView.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import SwiftUI

// MARK: - DangerZoneView

/// Danger zone with project deletion
struct DangerZoneView: View {
    // MARK: Lifecycle

    init(viewModel: ProjectSettingsViewModel) {
        self.viewModel = viewModel
    }

    // MARK: Internal

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Delete Project", systemImage: "trash")
                        .font(.headline)
                        .foregroundStyle(.red)

                    Text(
                        "Once you delete a project, there is no going back. "
                            + "This action publishes a deletion event to Nostr."
                    )
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                    Button {
                        showingDeleteConfirmation = true
                    } label: {
                        Label("Delete This Project", systemImage: "trash.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .disabled(isDeleting)

                    if isDeleting {
                        HStack {
                            ProgressView()
                            Text("Deleting...")
                        }
                    }
                }
                .padding(.vertical, 8)
            }
        }
        .navigationTitle("Danger Zone")
        .confirmationDialog(
            "Delete Project?",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Project", role: .destructive) {
                Task {
                    isDeleting = true
                    do {
                        try await viewModel.deleteProject()
                        dismiss()
                    } catch {
                        deleteError = error.localizedDescription
                        isDeleting = false
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This action cannot be undone. The project will be permanently deleted from Nostr.")
        }
        .alert("Error", isPresented: .constant(deleteError != nil)) {
            Button("OK") { deleteError = nil }
        } message: {
            Text(deleteError ?? "")
        }
    }

    // MARK: Private

    @Environment(\.dismiss) private var dismiss
    @State private var showingDeleteConfirmation = false
    @State private var isDeleting = false
    @State private var deleteError: String?

    @Bindable private var viewModel: ProjectSettingsViewModel
}
