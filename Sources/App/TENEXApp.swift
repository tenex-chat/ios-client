//
// TENEXApp.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import NDKSwiftCore
import NDKSwiftNostrDB
import os
import SwiftUI
import TENEXCore
import TENEXFeatures

// MARK: - TENEXApp

@main
struct TENEXApp: App {
    // MARK: Lifecycle

    init() {
        // NDK will be initialized asynchronously in .task with NostrDB cache
    }

    // MARK: Internal

    // MARK: - Body

    var body: some Scene {
        WindowGroup {
            Group {
                if let authManager, let ndk {
                    ContentView()
                        .environment(authManager)
                        .environment(\.ndk, ndk)
                        .environment(\.aiConfig, aiConfig)
                        .onChange(of: authManager.activePubkey) { oldPubkey, newPubkey in
                            handleAuthChange(oldPubkey: oldPubkey, newPubkey: newPubkey)
                        }
                        .environment(dataStore)
                } else {
                    ProgressView("Initializing...")
                }
            }
            .task {
                await initializeApp()
            }
        }
    }

    // MARK: Private

    // MARK: - State

    @State private var ndk: NDK?
    @State private var authManager: NDKAuthManager?
    @State private var dataStore: DataStore?
    @State private var aiConfig: AIConfig?

    // MARK: - Helpers

    private func initializeApp() async {
        // Initialize NDK with NostrDB cache
        if ndk == nil {
            await initializeNDK()
        }

        guard let ndk, let authManager else {
            return
        }

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

    private func initializeNDK() async {
        guard let documentsPath = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first else {
            Logger().error("Failed to get documents directory")
            return
        }

        let dbPath = documentsPath.appendingPathComponent("tenex-nostrdb").path

        do {
            try FileManager.default.createDirectory(
                atPath: dbPath,
                withIntermediateDirectories: true
            )
            let cache = try await NDKNostrDBCache(path: dbPath)

            let initializedNDK = NDK(
                relayURLs: ["wss://tenex.chat"],
                cache: cache,
                outboxEnabled: false
            )

            ndk = initializedNDK
            authManager = NDKAuthManager(ndk: initializedNDK)
        } catch {
            Logger().error("Failed to initialize NostrDB: \(error). Using default cache.")
            let initializedNDK = NDK(
                relayURLs: ["wss://tenex.chat"],
                outboxEnabled: false
            )
            ndk = initializedNDK
            authManager = NDKAuthManager(ndk: initializedNDK)
        }
    }

    private func handleAuthChange(oldPubkey: String?, newPubkey: String?) {
        if let newPubkey {
            // User logged in or switched accounts - start subscriptions for new user
            dataStore?.startSubscriptions(for: newPubkey)
        } else if oldPubkey != nil {
            // User logged out - clear all data
            dataStore?.stopSubscriptions()
        }
    }

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
