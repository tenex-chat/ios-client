//
// SessionIntegrationTests.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation
import NDKSwift
@testable import TENEXFeatures
import Testing

@Suite("Session Integration Tests")
@MainActor
struct SessionIntegrationTests {
    // MARK: - Session Lifecycle Tests

    @Test("Complete authentication lifecycle: sign-in, restore, sign-out")
    func completeAuthenticationLifecycle() async throws {
        let storage = InMemorySecureStorage()

        // Phase 1: Sign in with valid credentials
        let authManager1 = AuthManager(storage: storage)
        let signer = try NDKPrivateKeySigner.generate()
        let nsec = try signer.nsec
        let pubkey = try await signer.pubkey

        try await authManager1.signIn(with: nsec)

        #expect(authManager1.isAuthenticated == true)
        #expect(authManager1.currentUser?.pubkey == pubkey)
        #expect(authManager1.signer != nil)

        // Verify credentials are persisted
        let storedNsec = try storage.retrieve(for: "nsec")
        let storedPubkey = try storage.retrieve(for: "pubkey")
        #expect(storedNsec == nsec)
        #expect(storedPubkey == pubkey)

        // Phase 2: Simulate app restart - restore session
        let authManager2 = AuthManager(storage: storage)
        #expect(authManager2.isAuthenticated == false) // Not authenticated yet

        try await authManager2.restoreSession()

        #expect(authManager2.isAuthenticated == true)
        #expect(authManager2.currentUser?.pubkey == pubkey)
        #expect(authManager2.signer != nil)

        // Phase 3: Sign out
        try await authManager2.signOut()

        #expect(authManager2.isAuthenticated == false)
        #expect(authManager2.currentUser == nil)
        #expect(authManager2.signer == nil)

        // Verify credentials are cleared
        let clearedNsec = try storage.retrieve(for: "nsec")
        let clearedPubkey = try storage.retrieve(for: "pubkey")
        #expect(clearedNsec == nil)
        #expect(clearedPubkey == nil)

        // Phase 4: Attempt to restore after sign-out
        let authManager3 = AuthManager(storage: storage)
        try await authManager3.restoreSession()

        #expect(authManager3.isAuthenticated == false)
        #expect(authManager3.currentUser == nil)
        #expect(authManager3.signer == nil)
    }

    @Test("Session restoration with corrupted credentials clears state")
    func sessionRestorationWithCorruptedCredentials() async throws {
        let storage = InMemorySecureStorage()

        // Store invalid credentials directly
        try storage.save("invalid-nsec", for: "nsec")
        try storage.save("invalid-pubkey", for: "pubkey")
        try storage.save("invalid-npub", for: "npub")

        let authManager = AuthManager(storage: storage)

        do {
            try await authManager.restoreSession()
            // Should either succeed with cleared state or throw
        } catch {
            // Expected behavior - invalid credentials should fail
        }

        // State should be cleared after failed restoration
        #expect(authManager.isAuthenticated == false)
        #expect(authManager.currentUser == nil)
        #expect(authManager.signer == nil)

        // Storage should be cleared
        let clearedNsec = try storage.retrieve(for: "nsec")
        #expect(clearedNsec == nil)
    }

    @Test("Multiple sign-in/sign-out cycles work correctly")
    func multipleSignInSignOutCycles() async throws {
        let storage = InMemorySecureStorage()
        let authManager = AuthManager(storage: storage)

        // First cycle
        let signer1 = try NDKPrivateKeySigner.generate()
        let nsec1 = try signer1.nsec
        let pubkey1 = try await signer1.pubkey

        try await authManager.signIn(with: nsec1)
        #expect(authManager.isAuthenticated == true)
        #expect(authManager.currentUser?.pubkey == pubkey1)

        try await authManager.signOut()
        #expect(authManager.isAuthenticated == false)

        // Second cycle with different credentials
        let signer2 = try NDKPrivateKeySigner.generate()
        let nsec2 = try signer2.nsec
        let pubkey2 = try await signer2.pubkey

        try await authManager.signIn(with: nsec2)
        #expect(authManager.isAuthenticated == true)
        #expect(authManager.currentUser?.pubkey == pubkey2)
        #expect(authManager.currentUser?.pubkey != pubkey1) // Different user

        try await authManager.signOut()
        #expect(authManager.isAuthenticated == false)
    }

    @Test("Session restoration preserves signer functionality")
    func sessionRestorationPreservesSigner() async throws {
        let storage = InMemorySecureStorage()

        // Sign in and verify signer works
        let authManager1 = AuthManager(storage: storage)
        let signer = try NDKPrivateKeySigner.generate()
        let nsec = try signer.nsec
        let pubkey = try await signer.pubkey

        try await authManager1.signIn(with: nsec)
        let signer1Pubkey = try await authManager1.signer?.pubkey
        #expect(signer1Pubkey == pubkey)

        // Restore session and verify signer still works
        let authManager2 = AuthManager(storage: storage)
        try await authManager2.restoreSession()

        let signer2Pubkey = try await authManager2.signer?.pubkey
        #expect(signer2Pubkey == pubkey)
        #expect(signer2Pubkey == signer1Pubkey)
    }
}
