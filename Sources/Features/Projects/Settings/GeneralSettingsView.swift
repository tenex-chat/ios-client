//
// GeneralSettingsView.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import SwiftUI

// MARK: - GeneralSettingsView

/// General settings for project (name, description, repo URL)
struct GeneralSettingsView: View {
    // MARK: Lifecycle

    init(viewModel: ProjectSettingsViewModel) {
        self.viewModel = viewModel
    }

    // MARK: Internal

    var body: some View {
        Form {
            Section(header: Text("Project Details")) {
                TextField("Project Title", text: $viewModel.title)

                TextField("Description", text: $viewModel.description, axis: .vertical)
                    .lineLimit(5 ... 10)

                TextField("Repository URL", text: $viewModel.repoURL)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }

            Section {
                Button("Save Changes") {
                    Task {
                        do {
                            try await viewModel.save()
                            showingSuccessAlert = true
                        } catch {
                            // Error handled by viewModel.saveError
                        }
                    }
                }
                .disabled(!viewModel.hasUnsavedChanges || viewModel.isSaving)

                if viewModel.isSaving {
                    HStack {
                        ProgressView()
                        Text("Saving...")
                    }
                }
            }
        }
        .navigationTitle("General")
        .alert("Project Updated", isPresented: $showingSuccessAlert) {
            Button("OK") {}
        } message: {
            Text("Your changes have been published to Nostr.")
        }
        .alert("Error", isPresented: .constant(viewModel.saveError != nil)) {
            Button("OK") { viewModel.saveError = nil }
        } message: {
            Text(viewModel.saveError ?? "")
        }
    }

    // MARK: Private

    @State private var showingSuccessAlert = false

    @Bindable private var viewModel: ProjectSettingsViewModel
}
