//
// CallSettingsView.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import SwiftUI
import TENEXCore

// MARK: - CallSettingsView

/// In-call settings overlay with quick toggles
public struct CallSettingsView: View {
    // MARK: Lifecycle

    public init(settings: Binding<VoiceCallSettings>) {
        _settings = settings
    }

    // MARK: Public

    public var body: some View {
        NavigationStack {
            Form {
                self.quickSettingsSection
                self.advancedSettingsLink
            }
            .navigationTitle("Call Settings")
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
        }
        .presentationDetents([.height(280)])
        .presentationDragIndicator(.visible)
        .presentationBackgroundInteraction(.enabled)
    }

    // MARK: Private

    @Binding private var settings: VoiceCallSettings

    @ViewBuilder private var quickSettingsSection: some View {
        Section("Quick Settings") {
            self.vadModePicker
            Toggle("Auto-speak Responses", isOn: self.$settings.autoTTS)
                .accessibilityLabel("Auto-speak agent responses")
        }
    }

    @ViewBuilder private var vadModePicker: some View {
        Picker("Voice Detection", selection: self.$settings.vadMode) {
            Text("Manual").tag(VADMode.disabled)
            Text("Push-to-Talk").tag(VADMode.pushToTalk)
            Text("Auto").tag(VADMode.auto)
            Text("Auto + Hold").tag(VADMode.autoWithHold)
        }
        .pickerStyle(.menu)
        .accessibilityLabel("Voice detection mode")
    }

    @ViewBuilder private var advancedSettingsLink: some View {
        Section {
            NavigationLink {
                VoiceCallSettingsView(settings: self.$settings)
            } label: {
                Label("Advanced Settings", systemImage: "gear")
            }
        }
    }
}
