//
// VoiceSelectionView.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import SwiftUI
import TENEXCore

// MARK: - VoiceSelectionView

/// View for selecting a voice with filters and preview
struct VoiceSelectionView: View {
    // MARK: Lifecycle

    init(
        provider: TTSProvider,
        apiKey: String,
        onSelect: @escaping (VoiceInfo) -> Void
    ) {
        self.provider = provider
        self.apiKey = apiKey
        self.onSelect = onSelect
        _viewModel = State(initialValue: VoiceSelectionViewModel())
    }

    // MARK: Internal

    let provider: TTSProvider
    let apiKey: String
    let onSelect: (VoiceInfo) -> Void

    var body: some View {
        List {
            searchSection
            filtersSection
            voicesSection
        }
        .navigationTitle("Select Voice")
        #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
            .task {
                await viewModel.fetchVoices(provider: provider, apiKey: apiKey)
            }
    }

    // MARK: Private

    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: VoiceSelectionViewModel

    private var hasActiveFilters: Bool {
        !viewModel.searchQuery.isEmpty ||
            viewModel.selectedGender != nil ||
            viewModel.selectedAccent != nil ||
            viewModel.selectedAge != nil ||
            viewModel.selectedUseCase != nil
    }

    @ViewBuilder private var searchSection: some View {
        Section {
            TextField("Search voices...", text: $viewModel.searchQuery)
        }
    }

    @ViewBuilder private var filtersSection: some View {
        if !viewModel.genderOptions.isEmpty {
            Section("Gender") {
                FilterPills(
                    options: viewModel.genderOptions,
                    selection: $viewModel.selectedGender
                )
            }
        }

        if !viewModel.accentOptions.isEmpty {
            Section("Accent") {
                FilterPills(
                    options: viewModel.accentOptions,
                    selection: $viewModel.selectedAccent
                )
            }
        }

        if !viewModel.ageOptions.isEmpty {
            Section("Age") {
                FilterPills(
                    options: viewModel.ageOptions,
                    selection: $viewModel.selectedAge
                )
            }
        }

        if !viewModel.useCaseOptions.isEmpty {
            Section("Use Case") {
                FilterPills(
                    options: viewModel.useCaseOptions,
                    selection: $viewModel.selectedUseCase
                )
            }
        }

        if hasActiveFilters {
            Section {
                Button("Clear All Filters") {
                    viewModel.clearFilters()
                }
                .foregroundStyle(.red)
            }
        }
    }

    @ViewBuilder private var voicesSection: some View {
        Section {
            voicesSectionContent
        }
    }

    @ViewBuilder private var voicesSectionContent: some View {
        if viewModel.isLoadingVoices {
            loadingView
        } else if let error = viewModel.fetchError {
            errorView(error: error)
        } else {
            voicesList
        }
    }

    @ViewBuilder private var loadingView: some View {
        HStack {
            Spacer()
            ProgressView()
            Text("Loading voices...")
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    @ViewBuilder private var voicesList: some View {
        ForEach(viewModel.filteredVoices) { voice in
            VoiceRow(
                voice: voice,
                isPreviewing: viewModel.previewingVoiceID == voice.id,
                onSelect: {
                    onSelect(voice)
                    dismiss()
                },
                onPreview: {
                    Task {
                        await viewModel.previewVoice(voice)
                    }
                }
            )
        }

        if viewModel.filteredVoices.isEmpty {
            ContentUnavailableView(
                "No voices match your filters",
                systemImage: "magnifyingglass",
                description: Text("Try clearing some filters")
            )
        }
    }

    @ViewBuilder private func errorView(error: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Failed to load voices", systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
                .font(.headline)

            Text(error)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - FilterPills

struct FilterPills: View {
    let options: [String]
    @Binding var selection: String?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                ForEach(options, id: \.self) { option in
                    Button {
                        selection = selection == option ? nil : option
                    } label: {
                        Text(option.capitalized)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(selection == option ? Color.accentColor : Color.secondary.opacity(0.2))
                            .foregroundStyle(selection == option ? .white : .primary)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - VoiceRow

struct VoiceRow: View {
    // MARK: Internal

    let voice: VoiceInfo
    let isPreviewing: Bool
    let onSelect: () -> Void
    let onPreview: () -> Void

    var body: some View {
        HStack {
            voiceInfoColumn

            Spacer()

            previewButton
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
    }

    // MARK: Private

    @ViewBuilder private var voiceInfoColumn: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(voice.name)
                .font(.headline)

            if let description = voice.description {
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let labels = voice.labels {
                voiceLabels(labels)
            }
        }
    }

    @ViewBuilder private var previewButton: some View {
        if voice.previewURL != nil {
            Button {
                onPreview()
            } label: {
                if isPreviewing {
                    ProgressView()
                } else {
                    Image(systemName: "play.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.blue)
                }
            }
            .disabled(isPreviewing)
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder private func voiceLabels(_ labels: VoiceLabels) -> some View {
        HStack(spacing: 4) {
            if let gender = labels.gender {
                Label(gender, systemImage: "person.fill")
                    .labelStyle(.iconOnly)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            if let accent = labels.accent {
                Text(accent)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}
