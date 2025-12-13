//
// TENEXApp.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import NDKSwiftCore
import SwiftUI
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
                .task {
                    // Initialize DataStore with NDK
                    if dataStore == nil {
                        dataStore = DataStore(ndk: ndk)
                    }

                    // Restore session on app launch
                    try? await authManager.restoreSession()

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
    @State private var ndk: NDK = {
        let ndk = NDK(
            relayURLs: [
                "wss://tenex.chat",
            ]
        )
        // Disable outbox model to query all connected relays
        // (outbox requires NIP-65 relay metadata which we don't have yet)
        ndk.outboxEnabled = false
        return ndk
    }()
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
