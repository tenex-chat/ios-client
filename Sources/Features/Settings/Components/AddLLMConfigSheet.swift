//
// AddLLMConfigSheet.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import SwiftUI
import TENEXCore

// MARK: - AddLLMConfigSheet

/// Sheet for adding or editing an LLM configuration
struct AddLLMConfigSheet: View {
    // MARK: Lifecycle

    init(
        settingsViewModel: AISettingsViewModel,
        editingConfig: LLMConfig?,
        existingAPIKey: String?,
        onDismiss: @escaping () -> Void
    ) {
        self.settingsViewModel = settingsViewModel
        self.onDismiss = onDismiss

        if let config = editingConfig, let key = existingAPIKey {
            _formViewModel = State(
                initialValue: AddLLMConfigViewModel(
                    config: config,
                    apiKey: key,
                    availableProviders: settingsViewModel.availableLLMProviders
                )
            )
            isEditing = true
        } else {
            _formViewModel = State(
                initialValue: AddLLMConfigViewModel(
                    availableProviders: settingsViewModel.availableLLMProviders
                )
            )
            isEditing = false
        }
    }

    // MARK: Internal

    var body: some View {
        NavigationStack {
            Form {
                nameSection
                providerSection
                modelSection
                baseURLSection
                apiKeySection
                helpSection
            }
            .navigationTitle(isEditing ? "Edit LLM Config" : "Add LLM Config")
            .toolbar {
                toolbarContent
            }
            .alert("Error", isPresented: .init(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK") {
                    errorMessage = nil
                }
            } message: {
                if let error = errorMessage {
                    Text(error)
                }
            }
        }
    }

    // MARK: Private

    @State private var formViewModel: AddLLMConfigViewModel
    @State private var isSaving = false
    @State private var errorMessage: String?

    private let settingsViewModel: AISettingsViewModel
    private let onDismiss: () -> Void
    private let isEditing: Bool

    @ToolbarContentBuilder private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") {
                onDismiss()
            }
        }

        ToolbarItem(placement: .confirmationAction) {
            if isSaving {
                ProgressView()
            } else {
                Button(isEditing ? "Save" : "Add") {
                    Task {
                        await saveConfig()
                    }
                }
                .disabled(!formViewModel.isValid)
            }
        }
    }

    @ViewBuilder private var nameSection: some View {
        Section {
            TextField("Configuration Name", text: $formViewModel.name)
                .textInputAutocapitalization(.words)
        } header: {
            Text("Name")
        } footer: {
            Text("A descriptive name for this configuration (e.g., \"Fast\", \"Quality\", \"Local\")")
        }
    }

    @ViewBuilder private var providerSection: some View {
        Section {
            Picker("Provider", selection: $formViewModel.provider) {
                ForEach(formViewModel.availableProviders, id: \.self) { provider in
                    Text(provider.displayName).tag(provider)
                }
            }
        } header: {
            Text("Provider")
        }
    }

    @ViewBuilder private var modelSection: some View {
        Section {
            TextField("Model", text: $formViewModel.model)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        } header: {
            Text("Model")
        } footer: {
            Text("Examples: \(formViewModel.exampleModels)")
        }
    }

    @ViewBuilder private var baseURLSection: some View {
        if formViewModel.requiresBaseURL {
            Section {
                TextField("Base URL", text: $formViewModel.baseURL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
            } header: {
                Text("Base URL")
            } footer: {
                Text("The base URL for API requests")
            }
        }
    }

    @ViewBuilder private var apiKeySection: some View {
        if formViewModel.provider != .appleIntelligence {
            Section {
                SecureField("API Key", text: $formViewModel.apiKey)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            } header: {
                Text("API Key")
            }
        }
    }

    @ViewBuilder private var helpSection: some View {
        Section {
            Text(formViewModel.providerHelpText)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private func saveConfig() async {
        guard formViewModel.validate() else {
            errorMessage = formViewModel.validationError
            return
        }

        isSaving = true
        defer { isSaving = false }

        do {
            let config = formViewModel.createConfig()

            if isEditing {
                try await settingsViewModel.updateLLMConfig(config, apiKey: formViewModel.apiKey)
            } else {
                try await settingsViewModel.addLLMConfig(config, apiKey: formViewModel.apiKey)
            }

            onDismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
