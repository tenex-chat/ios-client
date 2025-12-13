//
// AISettingsView.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import SwiftUI
import TENEXCore

// MARK: - AISettingsView

/// Main AI settings view
public struct AISettingsView: View {
    // MARK: Lifecycle

    public init(viewModel: AISettingsViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    // MARK: Public

    public var body: some View {
        Form {
            llmConfigsSection
            featureAssignmentsSection
            ttsSettingsSection
            sttSettingsSection
        }
        .navigationTitle("AI Settings")
        .toolbar {
            toolbarContent
        }
        .task {
            await viewModel.load()
        }
        .sheet(isPresented: $showingAddLLMConfig) {
            addLLMConfigSheet
        }
        .sheet(isPresented: $showingVoiceSelection) {
            voiceSelectionSheet
        }
        .alert("Error", isPresented: .init(
            get: { viewModel.saveError != nil || viewModel.loadError != nil },
            set: { if !$0 { viewModel.saveError = nil; viewModel.loadError = nil } }
        )) {
            Button("OK") {
                viewModel.saveError = nil
                viewModel.loadError = nil
            }
        } message: {
            Text(viewModel.saveError ?? viewModel.loadError ?? "")
        }
    }

    // MARK: Private

    @State private var viewModel: AISettingsViewModel
    @State private var showingAddLLMConfig = false
    @State private var showingVoiceSelection = false
    @State private var editingConfig: LLMConfig?

    @ToolbarContentBuilder private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            if viewModel.isSaving {
                ProgressView()
            } else if viewModel.hasUnsavedChanges {
                Button("Save") {
                    Task {
                        try? await viewModel.save()
                    }
                }
            }
        }
    }

    @ViewBuilder private var llmConfigsSection: some View {
        Section {
            ForEach(viewModel.config.llmConfigs) { config in
                LLMConfigRow(
                    config: config,
                    isActive: viewModel.config.activeLLMConfigID == config.id,
                    onSetActive: {
                        Task {
                            try? await viewModel.setActiveLLMConfig(id: config.id)
                        }
                    },
                    onEdit: {
                        editingConfig = config
                        showingAddLLMConfig = true
                    },
                    onDelete: {
                        Task {
                            try? await viewModel.removeLLMConfig(id: config.id)
                        }
                    }
                )
            }

            Button {
                editingConfig = nil
                showingAddLLMConfig = true
            } label: {
                Label("Add LLM Configuration", systemImage: "plus.circle")
            }
        } header: {
            Text("LLM Providers")
        }
    }

    @ViewBuilder private var featureAssignmentsSection: some View {
        Section {
            ForEach(AIFeature.allCases, id: \.self) { feature in
                Picker(feature.displayName, selection: binding(for: feature)) {
                    Text("Use Active Config").tag(nil as String?)
                    ForEach(viewModel.config.llmConfigs) { config in
                        Text(config.name).tag(config.id as String?)
                    }
                }
            }
        } header: {
            Text("Feature Assignments")
        } footer: {
            Text("Assign specific models to features. Defaults to active configuration.")
        }
    }

    @ViewBuilder private var ttsSettingsSection: some View {
        Section {
            Toggle("Enable Text-to-Speech", isOn: $viewModel.config.ttsSettings.enabled)

            if viewModel.config.ttsSettings.enabled {
                voicesButton
                speedSlider
                Toggle("Auto-speak Agent Responses", isOn: $viewModel.config.ttsSettings.autoSpeak)
            }
        } header: {
            Text("Text-to-Speech")
        }
    }

    @ViewBuilder private var voicesButton: some View {
        Button {
            showingVoiceSelection = true
        } label: {
            HStack {
                Text("Voices")
                Spacer()
                Text("\(viewModel.config.ttsSettings.voiceConfigs.count) selected")
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder private var speedSlider: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Speed")
            Slider(
                value: $viewModel.config.ttsSettings.speed,
                in: 0.5 ... 2.0,
                step: 0.1
            )
            HStack {
                Text("0.5x").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text("\(viewModel.config.ttsSettings.speed, specifier: "%.1f")x")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("2.0x").font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder private var sttSettingsSection: some View {
        Section {
            Toggle("Enable Speech-to-Text", isOn: $viewModel.config.sttSettings.enabled)

            if viewModel.config.sttSettings.enabled {
                Picker("Provider", selection: $viewModel.config.sttSettings.provider) {
                    ForEach(viewModel.availableSTTProviders, id: \.self) { provider in
                        Text(provider.displayName).tag(provider)
                    }
                }

                TextField("Model", text: $viewModel.config.sttSettings.model)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
        } header: {
            Text("Speech-to-Text")
        }
    }

    @ViewBuilder private var addLLMConfigSheet: some View {
        if let config = editingConfig,
           let apiKey = try? viewModel.getAPIKey(for: config.id) {
            AddLLMConfigSheet(
                settingsViewModel: viewModel,
                editingConfig: config,
                existingAPIKey: apiKey
            ) {
                showingAddLLMConfig = false
                editingConfig = nil
            }
        } else {
            AddLLMConfigSheet(
                settingsViewModel: viewModel,
                editingConfig: nil,
                existingAPIKey: nil
            ) {
                showingAddLLMConfig = false
                editingConfig = nil
            }
        }
    }

    @ViewBuilder private var voiceSelectionSheet: some View {
        VoiceSelectionSheet(
            currentVoices: viewModel.config.ttsSettings.voiceConfigs
        ) { selectedVoices in
            viewModel.config.ttsSettings.voiceConfigs = selectedVoices
            showingVoiceSelection = false
        }
    }

    private func binding(for feature: AIFeature) -> Binding<String?> {
        Binding(
            get: { viewModel.config.featureAssignments[feature] },
            set: { newValue in
                Task {
                    try? await viewModel.setFeatureAssignment(feature: feature, configID: newValue)
                }
            }
        )
    }
}

// MARK: - Extensions

extension AIFeature {
    var displayName: String {
        switch self {
        case .titleGeneration:
            "Title Generation"
        case .summarization:
            "Summarization"
        case .systemPrompt:
            "System Prompt Assistance"
        }
    }
}

extension LLMProvider {
    var displayName: String {
        switch self {
        case .openai:
            "OpenAI"
        case .anthropic:
            "Anthropic"
        case .google:
            "Google"
        case .openrouter:
            "OpenRouter"
        case .ollama:
            "Ollama"
        case .appleIntelligence:
            "Apple Intelligence"
        }
    }
}

extension STTProvider {
    var displayName: String {
        switch self {
        case .whisper:
            "OpenAI Whisper"
        case .elevenlabs:
            "ElevenLabs"
        case .speechTranscriber:
            "Apple SpeechTranscriber"
        case .whisperKit:
            "WhisperKit"
        }
    }
}
