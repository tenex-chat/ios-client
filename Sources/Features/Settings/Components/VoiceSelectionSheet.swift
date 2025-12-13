//
// VoiceSelectionSheet.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import SwiftUI
import TENEXCore

// MARK: - VoiceSelectionSheet

/// Sheet for selecting multiple voices
struct VoiceSelectionSheet: View {
    // MARK: Lifecycle

    init(
        currentVoices: [VoiceConfig],
        onDone: @escaping ([VoiceConfig]) -> Void
    ) {
        _viewModel = State(initialValue: VoiceSelectionViewModel(currentVoices: currentVoices))
        self.onDone = onDone
    }

    // MARK: Internal

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchAndFilterSection

                List {
                    ForEach(viewModel.availableVoices) { voice in
                        voiceRow(for: voice)
                    }
                }
                .listStyle(.plain)

                selectionFooter
            }
            .navigationTitle("Select Voices")
            .toolbar {
                toolbarContent
            }
        }
    }

    // MARK: Private

    @State private var viewModel: VoiceSelectionViewModel

    private let onDone: ([VoiceConfig]) -> Void

    @ToolbarContentBuilder private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") {
                onDone([])
            }
        }

        ToolbarItem(placement: .confirmationAction) {
            Button("Done") {
                let configs = viewModel.createVoiceConfigs()
                onDone(configs)
            }
        }
    }

    @ViewBuilder private var searchAndFilterSection: some View {
        VStack(spacing: 12) {
            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)

                TextField("Search voices", text: $viewModel.searchQuery)
                    .textFieldStyle(.plain)

                if !viewModel.searchQuery.isEmpty {
                    Button {
                        viewModel.searchQuery = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
            .cornerRadius(10)

            // Provider filter
            Picker("Provider", selection: $viewModel.selectedProvider) {
                Text("All Providers").tag(nil as TTSProvider?)
                ForEach(TTSProvider.allCases, id: \.self) { provider in
                    Text(provider.displayName).tag(provider as TTSProvider?)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding()
        .background(Color(.systemGroupedBackground))
    }

    @ViewBuilder private var selectionFooter: some View {
        HStack {
            Text("\(viewModel.selectedCount)/\(viewModel.maxVoices) voices selected")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding()
        .background(Color(.systemGroupedBackground))
    }

    @ViewBuilder
    private func voiceRow(for voice: VoiceOption) -> some View {
        Button {
            viewModel.toggleVoice(id: voice.id)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(voice.displayText)
                        .foregroundStyle(.primary)

                    Text(voice.provider.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if viewModel.isSelected(voice.id) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.blue)
                } else if viewModel.isAtMaximum {
                    Image(systemName: "circle")
                        .foregroundStyle(.gray.opacity(0.3))
                } else {
                    Image(systemName: "circle")
                        .foregroundStyle(.gray)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isAtMaximum && !viewModel.isSelected(voice.id))
    }
}

// MARK: - Extensions

extension TTSProvider {
    var displayName: String {
        switch self {
        case .openai:
            "OpenAI"
        case .elevenlabs:
            "ElevenLabs"
        case .system:
            "System"
        }
    }
}
