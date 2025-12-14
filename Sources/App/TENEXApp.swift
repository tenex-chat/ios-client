//
// TENEXApp.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import NDKSwiftCore
import SwiftUI
import TENEXCore
import TENEXFeatures

// MARK: - TENEXApp

@main
struct TENEXApp: App {
    // MARK: Lifecycle

    init() {
        // Create NDK first
        let ndk = NDK(
            relayURLs: [
                "wss://tenex.chat",
            ],
            outboxEnabled: false
        )
        _ndk = State(initialValue: ndk)

        // Create auth manager with NDK reference
        _authManager = State(initialValue: NDKAuthManager(ndk: ndk))
    }

    // MARK: Internal

    // MARK: - Body

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(authManager)
                .environment(\.ndk, ndk)
                .environment(\.aiConfig, aiConfig)
                .task {
                    // Load AI configuration
                    await loadAIConfig()

                    // Initialize DataStore with NDK
                    if dataStore == nil {
                        dataStore = DataStore(ndk: ndk)
                    }

                    // Initialize auth manager (restores sessions and sets ndk.signer automatically)
                    await authManager.initialize()

                    // Connect to relays
                    await ndk.connect()

                    // Start data subscriptions after auth
                    if authManager.isAuthenticated, let pubkey = authManager.activePubkey {
                        dataStore?.startSubscriptions(for: pubkey)
                    }
                }
                .environment(dataStore)
        }
    }

    // MARK: Private

    // MARK: - State

    @State private var ndk: NDK
    @State private var authManager: NDKAuthManager
    @State private var dataStore: DataStore?
    @State private var aiConfig: AIConfig?

    // MARK: - Helpers

    /// Load AI configuration from storage
    private func loadAIConfig() async {
        let keychain = KeychainStorage(service: "com.tenex.ai")
        let storage = UserDefaultsAIConfigStorage(keychain: keychain)
        aiConfig = try? storage.load()
    }
}

// MARK: - ContentView

struct ContentView: View {
    // MARK: Internal

    var body: some View {
        Group {
            if authManager.isAuthenticated {
                NavigationShell()
            } else {
                LoginView(viewModel: LoginViewModel(authManager: authManager))
            }
        }
    }

    // MARK: Private

    @Environment(NDKAuthManager.self) private var authManager
}
