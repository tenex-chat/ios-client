//
// SettingsView.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import NDKSwiftCore
import SwiftUI
import TENEXCore

// MARK: - SettingsView

/// Main settings screen
public struct SettingsView: View {
    // MARK: Lifecycle

    public init() {}

    // MARK: Public

    public var body: some View {
        List {
            Section("General") {
                NavigationLink(destination: aiSettingsView) {
                    SettingsRow(
                        icon: "brain",
                        title: "AI Settings",
                        subtitle: "Configure LLM, TTS, and STT providers",
                        color: .blue
                    )
                }
            }

            Section("Developer") {
                NavigationLink(destination: DeveloperToolsView()) {
                    SettingsRow(
                        icon: "wrench.and.screwdriver",
                        title: "Developer Tools",
                        subtitle: "Debugging and diagnostics",
                        color: .gray
                    )
                }
            }
        }
        .navigationTitle("Settings")
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    // MARK: Private

    @ViewBuilder private var aiSettingsView: some View {
        let keychain = KeychainStorage(service: "com.tenex.ai")
        let storage = UserDefaultsAIConfigStorage(keychain: keychain)
        let capabilityDetector = RuntimeAICapabilityDetector()
        let viewModel = AISettingsViewModel(storage: storage, capabilityDetector: capabilityDetector)
        AISettingsView(viewModel: viewModel)
    }
}
