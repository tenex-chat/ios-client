//
// AgentProfileView.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import NDKSwiftCore
import SwiftUI
import TENEXCore

// MARK: - AgentProfileView

/// View displaying an agent's profile with Feed and Settings tabs
public struct AgentProfileView: View {
    // MARK: Lifecycle

    public init(pubkey: String, ndk: NDK) {
        self.pubkey = pubkey
        _viewModel = State(initialValue: AgentProfileViewModel(pubkey: pubkey, ndk: ndk))
    }

    // MARK: Public

    public var body: some View {
        VStack(spacing: 0) {
            AgentProfileTabBar(selectedTab: $selectedTab)
            Divider()

            Group {
                switch selectedTab {
                case .feed:
                    FeedTabView(viewModel: viewModel)
                case .settings:
                    SettingsTabView(pubkey: pubkey)
                }
            }
        }
        .navigationTitle(viewModel.agentName ?? "Agent Profile")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadAgentInfo()
        }
    }

    // MARK: Private

    @State private var viewModel: AgentProfileViewModel
    @State private var selectedTab: AgentProfileTab = .feed

    private let pubkey: String
}

// MARK: - FeedTabView

/// Feed tab showing all events from the agent's pubkey
private struct FeedTabView: View {
    // MARK: Internal

    let viewModel: AgentProfileViewModel

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.events.isEmpty {
                emptyView
            } else {
                eventList
            }
        }
    }

    // MARK: Private

    private var emptyView: some View {
        VStack(spacing: 20) {
            Image(systemName: "tray")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            Text("No Events")
                .font(.title2)
                .fontWeight(.semibold)

            Text("This agent hasn't published any events yet")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var eventList: some View {
        List {
            ForEach(viewModel.events, id: \.id) { event in
                EventRow(event: event)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }
        }
        .listStyle(.plain)
        .refreshable {
            await viewModel.refreshEvents()
        }
    }
}

// MARK: - EventRow

/// Row displaying a single event
private struct EventRow: View {
    // MARK: Internal

    let event: NDKEvent

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Kind \(event.kind.rawValue)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.blue.opacity(0.1))
                    .foregroundStyle(.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 4))

                Spacer()

                Text(formattedDate)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !event.content.isEmpty {
                Text(event.content)
                    .font(.body)
                    .lineLimit(3)
            }

            if !event.tags.isEmpty {
                Text("\(event.tags.count) tags")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: Private

    private var formattedDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: event.createdDate, relativeTo: Date())
    }
}

// MARK: - SettingsTabView

/// Settings tab for voice configuration
private struct SettingsTabView: View {
    // MARK: Lifecycle

    init(pubkey: String) {
        self.pubkey = pubkey
        _storage = State(initialValue: AgentVoiceConfigStorage())
        _config = State(initialValue: AgentVoiceConfigStorage().config(for: pubkey))
    }

    // MARK: Internal

    var body: some View {
        Form {
            Section {
                voicePicker
                speedSlider
            } header: {
                Text("Voice Configuration")
            } footer: {
                Text("Configure the voice and playback speed for this agent. These settings apply across all projects.")
            }

            Section {
                Button("Reset to Default", role: .destructive) {
                    config = nil
                    storage.removeConfig(for: pubkey)
                }
                .disabled(config == nil)
            }
        }
    }

    // MARK: Private

    @State private var storage: AgentVoiceConfigStorage
    @State private var config: AgentVoiceConfig?
    @Environment(\.aiConfig) private var aiConfig

    private let pubkey: String

    private var voicePicker: some View {
        let voices = aiConfig?.ttsSettings.voiceConfigs ?? []
        let defaultVoiceID = voices.first?.voiceID ?? "alloy"

        return Picker("Voice", selection: Binding(
            get: { config?.voiceID ?? defaultVoiceID },
            set: { newVoiceID in
                if config == nil {
                    config = AgentVoiceConfig(voiceID: newVoiceID)
                } else {
                    config?.voiceID = newVoiceID
                }
                if let config {
                    storage.setConfig(config, for: pubkey)
                }
            }
        )) {
            if voices.isEmpty {
                Text("Default Voice").tag("alloy")
            } else {
                ForEach(voices, id: \.id) { voice in
                    Text(voice.name).tag(voice.voiceID)
                }
            }
        }
    }

    private var speedSlider: some View {
        let defaultSpeed = aiConfig?.ttsSettings.speed ?? 1.0

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Speed")
                Spacer()
                Text(String(format: "%.1fx", config?.speed ?? defaultSpeed))
                    .foregroundStyle(.secondary)
            }

            Slider(
                value: Binding(
                    get: { config?.speed ?? defaultSpeed },
                    set: { newSpeed in
                        if config == nil {
                            let voices = aiConfig?.ttsSettings.voiceConfigs ?? []
                            let voiceID = voices.first?.voiceID ?? "alloy"
                            config = AgentVoiceConfig(voiceID: voiceID, speed: newSpeed)
                        } else {
                            config?.speed = newSpeed
                        }
                        if let config {
                            storage.setConfig(config, for: pubkey)
                        }
                    }
                ),
                in: 0.5 ... 2.0,
                step: 0.1
            )
        }
    }
}
