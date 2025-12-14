//
// ModelBrowserSheet.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import SwiftUI
import TENEXCore

/// Sheet for browsing and selecting available models
struct ModelBrowserSheet: View {
    // MARK: Lifecycle

    init(viewModel: AddLLMConfigViewModel) {
        _viewModel = Bindable(viewModel)
    }

    // MARK: Internal

    @Bindable var viewModel: AddLLMConfigViewModel

    var body: some View {
        NavigationStack {
            List {
                listContent
            }
            .searchable(text: $searchText, prompt: "Search models")
            .navigationTitle("Select Model")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        viewModel.showModelBrowser = false
                    }
                }
            }
        }
    }

    // MARK: Private

    @State private var searchText = ""

    private var filteredModels: [ModelInfo] {
        if searchText.isEmpty {
            return viewModel.availableModels
        }

        let query = searchText.lowercased()
        return viewModel.availableModels.filter {
            $0.id.lowercased().contains(query) ||
                $0.name.lowercased().contains(query) ||
                $0.description?.lowercased().contains(query) == true
        }
    }

    @ViewBuilder private var listContent: some View {
        if viewModel.isLoadingModels {
            loadingSection
        } else if let error = viewModel.modelFetchError {
            errorSection(error: error)
        } else {
            modelsListSection
        }
    }

    @ViewBuilder private var loadingSection: some View {
        Section {
            HStack {
                Spacer()
                ProgressView()
                Text("Loading models...")
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
    }

    @ViewBuilder private var modelsListSection: some View {
        Section {
            ForEach(filteredModels) { model in
                modelRow(model)
            }
        } header: {
            if !filteredModels.isEmpty {
                Text("\(filteredModels.count) models found")
            }
        }

        if filteredModels.isEmpty, !searchText.isEmpty {
            emptySearchSection
        }
    }

    @ViewBuilder private var emptySearchSection: some View {
        Section {
            ContentUnavailableView(
                "No models match your search",
                systemImage: "magnifyingglass",
                description: Text("Try a different search term")
            )
        }
    }

    @ViewBuilder private func errorSection(error: String) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Label("Failed to load models", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .font(.headline)

                Text(error)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("You can still enter the model name manually.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder private func modelRow(_ model: ModelInfo) -> some View {
        Button {
            viewModel.selectModel(model)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(model.name)
                    .font(.headline)
                    .foregroundStyle(.primary)

                if let description = model.description {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let contextLength = model.contextLength {
                    Text("\(contextLength.formatted()) token context")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }
}
