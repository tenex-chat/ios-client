//
// VoiceCallSettingsView.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import SwiftUI
import TENEXCore

// MARK: - VoiceCallSettingsView

/// Comprehensive voice call configuration settings
public struct VoiceCallSettingsView: View {
    // MARK: Lifecycle

    public init(settings: Binding<VoiceCallSettings>) {
        _settings = settings
    }

    // MARK: Public

    public var body: some View {
        Form {
            self.voiceDetectionSection
            self.audioProcessingSection
            self.callBehaviorSection
        }
        .navigationTitle("Voice Call")
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    // MARK: Private

    @Binding private var settings: VoiceCallSettings

    private var vadModeFooterText: String {
        switch self.settings.vadMode {
        case .disabled:
            "Manually control recording with the mic button."
        case .pushToTalk:
            "Tap to start recording, tap again to stop."
        case .auto:
            "Automatically detects when you start and stop speaking."
        case .autoWithHold:
            "Auto-detect with tap-and-hold to keep mic open while thinking."
        }
    }

    @ViewBuilder private var voiceDetectionSection: some View {
        Section {
            self.vadModePicker

            if self.settings.vadMode == .auto || self.settings.vadMode == .autoWithHold {
                self.vadMethodPicker
                self.vadSensitivitySlider
            }
        } header: {
            Text("Voice Detection")
        } footer: {
            Text(self.vadModeFooterText)
        }
    }

    @ViewBuilder private var vadModePicker: some View {
        Picker("Detection Mode", selection: self.$settings.vadMode) {
            ForEach(VADMode.allCases, id: \.self) { mode in
                Text(mode.displayName).tag(mode)
            }
        }
        .accessibilityLabel("Voice detection mode")
    }

    @ViewBuilder private var vadMethodPicker: some View {
        Picker("Detection Method", selection: self.$settings.vadMethod) {
            ForEach(VADMethod.allCases, id: \.self) { method in
                VStack(alignment: .leading, spacing: 2) {
                    Text(method.displayName)
                    Text(method.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .tag(method)
            }
        }
        .accessibilityLabel("Voice detection method")
    }

    @ViewBuilder private var vadSensitivitySlider: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Sensitivity")
            Slider(value: self.$settings.vadSensitivity, in: 0 ... 1, step: 0.1)
                .accessibilityLabel("VAD sensitivity")
                .accessibilityValue("\(Int(self.settings.vadSensitivity * 100)) percent")
            HStack {
                Text("Low").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text("\(Int(self.settings.vadSensitivity * 100))%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("High").font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder private var audioProcessingSection: some View {
        Section("Audio Processing") {
            Toggle("Noise Suppression", isOn: self.$settings.noiseSuppression)
                .accessibilityLabel("Enable noise suppression")
            Toggle("Echo Cancellation", isOn: self.$settings.echoCancellation)
                .accessibilityLabel("Enable echo cancellation")
            Toggle("Auto Gain Control", isOn: self.$settings.autoGainControl)
                .accessibilityLabel("Enable auto gain control")
        }
    }

    @ViewBuilder private var callBehaviorSection: some View {
        Section {
            Toggle("Record Calls", isOn: self.$settings.enableVOD)
                .accessibilityLabel("Enable call recording")
        } header: {
            Text("Call Behavior")
        } footer: {
            if self.settings.enableVOD {
                Text("Call recordings are stored locally for playback.")
            }
        }
    }
}

// MARK: - VADMode Extensions

extension VADMode {
    var displayName: String {
        switch self {
        case .disabled:
            "Disabled"
        case .pushToTalk:
            "Push-to-Talk"
        case .auto:
            "Auto-Detect"
        case .autoWithHold:
            "Auto + Hold Override"
        }
    }
}

// MARK: - VADMethod Extensions

extension VADMethod {
    var displayName: String {
        switch self {
        case .energyBased:
            "Energy-Based"
        case .appleSpeech:
            "Apple Speech (iOS 18+)"
        }
    }

    var description: String {
        switch self {
        case .energyBased:
            "Simple loudness detection, works on all versions"
        case .appleSpeech:
            "ML-powered speech detection, more accurate"
        }
    }
}
