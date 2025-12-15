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
            AgentProfileTabBar(selectedTab: self.$selectedTab)
            Divider()

            Group {
                switch self.selectedTab {
                case .feed:
                    AgentFeedTabView(viewModel: self.viewModel)
                case .settings:
                    SettingsTabView(pubkey: self.pubkey)
                }
            }
        }
        .navigationTitle(self.viewModel.agentName ?? "Agent Profile")
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .tabBar)
        #endif
            .onAppear {
                self.viewModel.startSubscriptions()
            }
    }

    // MARK: Private

    @State private var viewModel: AgentProfileViewModel
    @State private var selectedTab: AgentProfileTab = .feed

    private let pubkey: String
}

// MARK: - AgentFeedTabView

/// Feed tab showing all events from the agent's pubkey
private struct AgentFeedTabView: View {
    // MARK: Internal

    let viewModel: AgentProfileViewModel

    var body: some View {
        Group {
            if self.viewModel.events.isEmpty {
                self.emptyView
            } else {
                self.eventList
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
            ForEach(self.viewModel.events, id: \.id) { event in
                EventRow(event: event)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }
        }
        .listStyle(.plain)
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
                Text("Kind \(self.event.kind)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.blue.opacity(0.1))
                    .foregroundStyle(.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 4))

                Spacer()

                Text(self.formattedDate)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !self.event.content.isEmpty {
                Text(self.event.content)
                    .font(.body)
                    .lineLimit(3)
            }

            if !self.event.tags.isEmpty {
                Text("\(self.event.tags.count) tags")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .contextMenu {
            self.contextMenuContent
        }
        .sheet(isPresented: self.$showRawEvent) {
            RawEventSheet(rawEventJSON: self.event.asJSON, isPresented: self.$showRawEvent)
        }
    }

    // MARK: Private

    @State private var showRawEvent = false

    private var formattedDate: String {
        let date = Date(timeIntervalSince1970: TimeInterval(event.createdAt))
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    @ViewBuilder private var contextMenuContent: some View {
        Button {
            self.copyToClipboard(self.event.id)
        } label: {
            Label("Copy ID", systemImage: "number")
        }

        Button {
            self.copyToClipboard(self.event.content)
        } label: {
            Label("Copy Content", systemImage: "doc.on.doc")
        }

        if let rawEventJSON = event.asJSON {
            Button {
                self.copyToClipboard(rawEventJSON)
            } label: {
                Label("Copy Raw Event", systemImage: "doc.on.doc.fill")
            }
        }

        Button {
            self.showRawEvent = true
        } label: {
            Label("View Raw Event", systemImage: "chevron.left.forwardslash.chevron.right")
        }
    }

    private func copyToClipboard(_ text: String) {
        #if os(iOS)
            UIPasteboard.general.string = text
        #else
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
        #endif
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
                self.voicePicker
                self.speedSlider
            } header: {
                Text("Voice Configuration")
            } footer: {
                Text("Configure the voice and playback speed for this agent. These settings apply across all projects.")
            }

            Section {
                Button("Reset to Default", role: .destructive) {
                    self.config = nil
                    self.storage.removeConfig(for: self.pubkey)
                }
                .disabled(self.config == nil)
            }
        }
    }

    // MARK: Private

    @State private var storage: AgentVoiceConfigStorage
    @State private var config: AgentVoiceConfig?
    @Environment(\.aiConfig) private var aiConfig

    private let pubkey: String

    private var voicePicker: some View {
        let voices = self.aiConfig?.ttsSettings.voiceConfigs ?? []
        let defaultVoiceID = voices.first?.voiceID ?? "alloy"

        return Picker("Voice", selection: Binding(
            get: { self.config?.voiceID ?? defaultVoiceID },
            set: { newVoiceID in
                if config == nil {
                    config = AgentVoiceConfig(voiceID: newVoiceID)
                } else {
                    config?.voiceID = newVoiceID
                }
                if let config {
                    self.storage.setConfig(config, for: self.pubkey)
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
        let defaultSpeed = self.aiConfig?.ttsSettings.speed ?? 1.0

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Speed")
                Spacer()
                Text(String(format: "%.1fx", self.config?.speed ?? defaultSpeed))
                    .foregroundStyle(.secondary)
            }

            Slider(
                value: Binding(
                    get: { self.config?.speed ?? defaultSpeed },
                    set: { newSpeed in
                        if config == nil {
                            let voices = self.aiConfig?.ttsSettings.voiceConfigs ?? []
                            let voiceID = voices.first?.voiceID ?? "alloy"
                            config = AgentVoiceConfig(voiceID: voiceID, speed: newSpeed)
                        } else {
                            config?.speed = newSpeed
                        }
                        if let config {
                            self.storage.setConfig(config, for: self.pubkey)
                        }
                    }
                ),
                in: 0.5 ... 2.0,
                step: 0.1
            )
        }
    }
}
