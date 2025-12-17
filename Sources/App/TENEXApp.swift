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
                if let authManager, let ndk, let aiConfigStorage, let audioService {
                    ContentView()
                        .environment(authManager)
                        .environment(\.ndk, ndk)
                        .environment(\.aiConfig, self.aiConfig)
                        .environment(\.aiConfigStorage, aiConfigStorage)
                        .environment(\.audioService, audioService)
                        .onChange(of: authManager.activePubkey) { oldPubkey, newPubkey in
                            self.handleAuthChange(oldPubkey: oldPubkey, newPubkey: newPubkey)
                        }
                        .environment(self.dataStore)
                        .environment(self.syncManager)
                        #if os(macOS)
                        .environment(self.windowManager)
                        #endif
                        .task {
                            await self.performInitialSyncIfNeeded()
                        }
                } else {
                    ProgressView("Initializing...")
                }
            }
            .task {
                await self.initializeApp()
            }
        }

        #if os(macOS)
        // MARK: - Detached Conversation Windows

        /// WindowGroup for detached conversation windows
        ///
        /// This WindowGroup creates separate macOS windows for conversations that have been detached
        /// from the main drawer. Each window displays a ChatView with header controls for reattaching
        /// or closing the window.
        ///
        /// The windowID (String) uniquely identifies the conversation window and is used to look up
        /// the window's metadata from WindowManagerStore.
        WindowGroup("Conversation", id: "conversation", for: String.self) { $windowID in
            if let windowID, let authManager, let ndk, let dataStore, let aiConfigStorage, let audioService {
                DetachedConversationWindow(
                    windowID: windowID,
                    ndk: ndk,
                    authManager: authManager,
                    dataStore: dataStore
                )
                .environment(authManager)
                .environment(\.ndk, ndk)
                .environment(\.aiConfig, self.aiConfig)
                .environment(\.aiConfigStorage, aiConfigStorage)
                .environment(\.audioService, audioService)
                .environment(dataStore)
                .environment(self.windowManager)
            }
        }
        .defaultSize(width: 800, height: 600)
        #endif
    }

    // MARK: Private

    // MARK: - State

    @State private var ndk: NDK?
    @State private var authManager: NDKAuthManager?
    @State private var dataStore: DataStore?
    @State private var syncManager: SyncManager?
    @State private var aiConfig: AIConfig?
    @State private var aiConfigStorage: AIConfigStorage?
    @State private var audioService: AudioService?
    @State private var hasPerformedInitialSync = false

    #if os(macOS)
    @State private var windowManager = WindowManagerStore()
    #endif

    // MARK: - Helpers

    private func initializeApp() async {
        // Initialize NDK with NostrDB cache
        if ndk == nil {
            await self.initializeNDK()
        }

        guard let ndk, let authManager else {
            return
        }

        // Load AI configuration
        await self.loadAIConfig()

        // Initialize DataStore with NDK
        if self.dataStore == nil {
            self.dataStore = DataStore(ndk: ndk)
        }

        // Initialize SyncManager with NDK
        if self.syncManager == nil {
            self.syncManager = SyncManager(ndk: ndk)
        }

        // Initialize auth manager (restores sessions and sets ndk.signer automatically)
        await authManager.initialize()

        // Connect to relays
        await ndk.connect()

        // Start data subscriptions after auth
        if authManager.isAuthenticated, let pubkey = authManager.activePubkey {
            self.dataStore?.startSubscriptions(for: pubkey)
        }
    }

    private func performInitialSyncIfNeeded() async {
        guard let authManager, authManager.isAuthenticated else {
            return
        }

        guard !hasPerformedInitialSync else {
            return
        }

        guard let dataStore, let syncManager else {
            return
        }

        // Wait for projects to load (with timeout)
        let maxWaitTime: TimeInterval = 10.0
        let pollInterval: TimeInterval = 0.5
        let startTime = Date()

        while dataStore.projects.isEmpty {
            if Date().timeIntervalSince(startTime) > maxWaitTime {
                Logger().info("No projects loaded after timeout, skipping initial sync")
                return
            }
            try? await Task.sleep(for: .seconds(pollInterval))
        }

        // Trigger initial sync
        Logger().info("Performing initial sync on app launch for \(dataStore.projects.count) projects")
        hasPerformedInitialSync = true
        await syncManager.syncAllProjects(dataStore.projects)
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

            self.ndk = initializedNDK
            self.authManager = NDKAuthManager(ndk: initializedNDK)
        } catch {
            Logger().error("Failed to initialize NostrDB: \(error). Using default cache.")
            let initializedNDK = NDK(
                relayURLs: ["wss://tenex.chat"],
                outboxEnabled: false
            )
            self.ndk = initializedNDK
            self.authManager = NDKAuthManager(ndk: initializedNDK)
        }
    }

    private func handleAuthChange(oldPubkey: String?, newPubkey: String?) {
        if let newPubkey {
            // User logged in or switched accounts - start subscriptions for new user
            self.dataStore?.startSubscriptions(for: newPubkey)
        } else if oldPubkey != nil {
            // User logged out - clear all data
            self.dataStore?.stopSubscriptions()
        }
    }

    /// Load AI configuration from storage
    private func loadAIConfig() async {
        let keychain = KeychainStorage(service: "com.tenex.ai")
        let storage = UserDefaultsAIConfigStorage(keychain: keychain)
        self.aiConfigStorage = storage
        self.aiConfig = try? storage.load()

        // Initialize AudioService
        let capabilityDetector = RuntimeAICapabilityDetector()
        self.audioService = AudioService(storage: storage, capabilityDetector: capabilityDetector)
    }
}

// MARK: - ContentView

struct ContentView: View {
    // MARK: Internal

    var body: some View {
        Group {
            if self.authManager.isAuthenticated {
                MainTabView()
            } else {
                LoginView(viewModel: LoginViewModel(authManager: self.authManager))
            }
        }
    }

    // MARK: Private

    @Environment(NDKAuthManager.self) private var authManager
}
