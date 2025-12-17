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
            self.accountSection
            self.generalSection
            self.dataSection
            self.developerSection
        }
        .navigationTitle("Settings")
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .tabBar)
        #endif
            .confirmationDialog(
                "Are you sure you want to sign out?",
                isPresented: self.$showingSignOutConfirmation,
                titleVisibility: .visible
            ) {
                Button("Sign Out", role: .destructive) {
                    self.authManager.logout()
                }
                Button("Cancel", role: .cancel) {}
            }
    }

    // MARK: Private

    @Environment(\.ndk) private var ndk
    @Environment(NDKAuthManager.self) private var authManager
    @Environment(DataStore.self) private var dataStore
    @Environment(SyncManager.self) private var syncManager
    @State private var showingSignOutConfirmation = false

    private var npub: String? {
        guard let pubkey = authManager.activePubkey else {
            return nil
        }
        return try? String.toNpub(pubkey)
    }

    private var accountSection: some View {
        Section("Account") {
            if let npub {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Logged in as")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(npub)
                        .font(.footnote)
                        .fontDesign(.monospaced)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .padding(.vertical, 4)
            }

            Button(role: .destructive) {
                self.showingSignOutConfirmation = true
            } label: {
                Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
            }
        }
    }

    private var generalSection: some View {
        Section("General") {
            NavigationLink(destination: self.aiSettingsView) {
                SettingsRow(
                    icon: "brain",
                    title: "AI Settings",
                    subtitle: "Configure LLM, TTS, and STT providers",
                    color: .blue
                )
            }

            NavigationLink(destination: self.voiceCallSettingsView) {
                SettingsRow(
                    icon: "phone.fill",
                    title: "Voice Call",
                    subtitle: "Voice detection, audio processing, and call behavior",
                    color: .green
                )
            }
        }
    }

    private var dataSection: some View {
        Section("Data") {
            NavigationLink(destination: self.syncView) {
                SettingsRow(
                    icon: "arrow.triangle.2.circlepath",
                    title: "Sync",
                    subtitle: "Sync projects and view history",
                    color: .purple
                )
            }
        }
    }

    private var developerSection: some View {
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

    @ViewBuilder private var aiSettingsView: some View {
        let keychain = KeychainStorage(service: "com.tenex.ai")
        let storage = UserDefaultsAIConfigStorage(keychain: keychain)
        let capabilityDetector = RuntimeAICapabilityDetector()
        let viewModel = AISettingsViewModel(storage: storage, capabilityDetector: capabilityDetector)
        AISettingsView(viewModel: viewModel)
    }

    @ViewBuilder private var voiceCallSettingsView: some View {
        let keychain = KeychainStorage(service: "com.tenex.ai")
        let storage = UserDefaultsAIConfigStorage(keychain: keychain)
        VoiceCallSettingsViewWrapper(storage: storage)
    }

    @ViewBuilder private var syncView: some View {
        SyncHistoryView(syncManager: syncManager, projects: dataStore.projects)
    }
}

// MARK: - VoiceCallSettingsViewWrapper

/// Wrapper to load and persist voice call settings
private struct VoiceCallSettingsViewWrapper: View {
    // MARK: Lifecycle

    init(storage: AIConfigStorage) {
        self.storage = storage
    }

    // MARK: Internal

    var body: some View {
        VoiceCallSettingsView(settings: self.$settings)
            .task {
                await self.loadSettings()
            }
            .onChange(of: self.settings) {
                Task {
                    await self.saveSettings()
                }
            }
    }

    // MARK: Private

    @State private var settings = VoiceCallSettings()

    private let storage: AIConfigStorage

    private func loadSettings() async {
        if let config = try? storage.load() {
            self.settings = config.voiceCallSettings
        }
    }

    private func saveSettings() async {
        var config = (try? self.storage.load()) ?? AIConfig()
        config.voiceCallSettings = self.settings
        try? self.storage.save(config)
    }
}
