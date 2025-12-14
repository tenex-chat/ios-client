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

                    // Restore session on app launch
                    try? await authManager.restoreSession()

                    // Set signer on NDK from auth manager
                    if let signer = authManager.signer {
                        ndk.signer = signer
                    }

                    // Connect to relays
                    await ndk.connect()

                    // Start data subscriptions after auth
                    if authManager.isAuthenticated, let pubkey = authManager.currentUser?.pubkey {
                        dataStore?.startSubscriptions(for: pubkey)
                    }
                }
                .environment(dataStore)
        }
    }

    // MARK: Private

    // MARK: - State

    @State private var authManager = AuthManager()
    @State private var dataStore: DataStore?
    @State private var aiConfig: AIConfig?
    @State private var ndk: NDK = {
        // Disable outbox model to query all connected relays
        // (outbox requires NIP-65 relay metadata which we don't have yet)
        let ndk = NDK(
            relayURLs: [
                "wss://tenex.chat",
            ],
            outboxEnabled: false
        )
        return ndk
    }()

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

    @Environment(AuthManager.self) private var authManager
}
