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
                    // Restore session on app launch
                    try? await authManager.restoreSession()

                    // Connect to relays
                    await ndk.connect()
                }
        }
    }

    // MARK: Private

    // MARK: - State

    @State private var authManager = AuthManager()
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
