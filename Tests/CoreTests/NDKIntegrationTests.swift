//
// NDKIntegrationTests.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import NDKSwift
import Testing

@Suite("NDK Integration Tests")
struct NDKIntegrationTests {
    @Test("NDK connects to relay")
    func ndkConnectsToRelay() async throws {
        // Initialize NDK with relay
        let ndk = NDK(relayURLs: ["wss://relay.damus.io"])

        // Track connection state
        var connected = false

        // Observe relay connection state
        if let relay = ndk.relays.first {
            relay.observeConnectionState { state in
                if case .connected = state {
                    connected = true
                }
            }
        }

        // Connect to relays
        await ndk.connect()

        // Wait for connection to establish (up to 10 seconds)
        var attempts = 0
        while !connected, attempts < 100 {
            try await Task.sleep(for: .milliseconds(100))
            attempts += 1
        }

        // Verify we have at least one connected relay
        let connectedRelays = ndk.pool.connectedRelays()
        #expect(!connectedRelays.isEmpty, "Should have at least one connected relay")

        // Disconnect
        await ndk.disconnect()
    }
}
