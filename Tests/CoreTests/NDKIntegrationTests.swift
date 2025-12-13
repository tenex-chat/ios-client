//
// NDKIntegrationTests.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import NDKSwiftCore
import Testing

@Suite("NDK Integration Tests")
struct NDKIntegrationTests {
    @Test("NDK connects to relay")
    @MainActor
    func ndkConnectsToRelay() async throws {
        // Initialize NDK with relay
        let ndk = NDK(relayURLs: ["wss://tenex.chat"])

        // Connect to relays
        await ndk.connect()

        // Wait for connection to establish (up to 5 seconds)
        try await Task.sleep(for: .seconds(2))

        // Verify we have at least one connected relay
        let connectedRelays = await ndk.pool.connectedRelays()
        #expect(!connectedRelays.isEmpty, "Should have at least one connected relay")

        // Disconnect
        await ndk.disconnect()
    }
}
