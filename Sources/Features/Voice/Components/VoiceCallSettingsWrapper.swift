//
// VoiceCallSettingsWrapper.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import SwiftUI
import TENEXCore

// MARK: - VoiceCallSettingsWrapper

/// Wrapper to load and persist voice call settings from CallView
struct VoiceCallSettingsWrapper: View {
    // MARK: Lifecycle

    init(storage: AIConfigStorage, onDismiss: @escaping () -> Void) {
        self.storage = storage
        self.onDismiss = onDismiss
    }

    // MARK: Internal

    var body: some View {
        VoiceCallSettingsView(settings: self.$settings)
            .navigationTitle("Voice Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        self.onDismiss()
                    }
                }
            }
            .task {
                await self.loadSettings()
            }
            .onChange(of: self.settings) { _, _ in
                // Only save after initial load is complete
                guard self.hasLoaded else {
                    return
                }
                Task {
                    await self.saveSettings()
                }
            }
    }

    // MARK: Private

    @State private var settings = VoiceCallSettings()
    @State private var hasLoaded = false

    private let storage: AIConfigStorage
    private let onDismiss: () -> Void

    private func loadSettings() async {
        do {
            if let config = try storage.load() {
                self.settings = config.voiceCallSettings
            }
        } catch {}
        self.hasLoaded = true
    }

    private func saveSettings() async {
        do {
            // Try to load existing config, or create fresh one if load fails
            var config = (try? self.storage.load()) ?? AIConfig()
            config.voiceCallSettings = self.settings
            try self.storage.save(config)
        } catch {}
    }
}
