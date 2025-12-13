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
        .commands {
            SidebarCommands()
        }
    }

    // MARK: Private

    // MARK: - State

    @State private var authManager = AuthManager()
    @State private var ndk = NDK(
        relayURLs: [
            "wss://tenex.chat",
        ]
    )
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
