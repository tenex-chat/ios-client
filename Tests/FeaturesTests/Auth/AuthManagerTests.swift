//
// AuthManagerTests.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation
import NDKSwift
@testable import TENEXFeatures
import Testing

@Suite("AuthManager Tests")
@MainActor
struct AuthManagerTests {
    // MARK: - Session State Tests

    @Test("AuthManager starts in logged out state")
    func startsLoggedOut() async throws {
        let storage = InMemorySecureStorage()
        let authManager = AuthManager(storage: storage)

        #expect(authManager.isAuthenticated == false)
        #expect(authManager.currentUser == nil)
    }

    @Test("AuthManager stores credentials on sign in")
    func storesCredentialsOnSignIn() async throws {
        let storage = InMemorySecureStorage()
        let authManager = AuthManager(storage: storage)

        // Generate a test private key
        let signer = try NDKPrivateKeySigner.generate()
        let nsec = try signer.nsec
        let pubkey = try await signer.pubkey

        // Sign in
        try await authManager.signIn(with: nsec)

        #expect(authManager.isAuthenticated == true)
        #expect(authManager.currentUser != nil)
        #expect(authManager.currentUser?.pubkey == pubkey)

        // Verify stored in storage
        let storedNsec = try storage.retrieve(for: "nsec")
        #expect(storedNsec == nsec)
    }

    @Test("AuthManager retrieves credentials from storage")
    func retrievesCredentials() async throws {
        let storage = InMemorySecureStorage()

        // Generate and store credentials
        let signer = try NDKPrivateKeySigner.generate()
        let nsec = try signer.nsec
        let pubkey = try await signer.pubkey
        let npub = try signer.npub

        try storage.save(nsec, for: "nsec")
        try storage.save(pubkey, for: "pubkey")
        try storage.save(npub, for: "npub")

        // Create manager (should restore session)
        let authManager = AuthManager(storage: storage)
        try await authManager.restoreSession()

        #expect(authManager.isAuthenticated == true)
        #expect(authManager.currentUser?.pubkey == pubkey)
    }

    @Test("AuthManager deletes credentials on sign out")
    func deletesCredentialsOnSignOut() async throws {
        let storage = InMemorySecureStorage()
        let authManager = AuthManager(storage: storage)

        // Sign in
        let signer = try NDKPrivateKeySigner.generate()
        let nsec = try signer.nsec

        try await authManager.signIn(with: nsec)
        #expect(authManager.isAuthenticated == true)

        // Sign out
        try await authManager.signOut()

        #expect(authManager.isAuthenticated == false)
        #expect(authManager.currentUser == nil)

        // Verify deleted from storage
        let storedNsec = try storage.retrieve(for: "nsec")
        #expect(storedNsec == nil)
    }

    @Test("AuthManager restores session on app launch")
    func restoresSessionOnLaunch() async throws {
        let storage = InMemorySecureStorage()

        // First session: sign in
        let authManager1 = AuthManager(storage: storage)
        let signer = try NDKPrivateKeySigner.generate()
        let nsec = try signer.nsec
        let pubkey = try await signer.pubkey

        try await authManager1.signIn(with: nsec)
        #expect(authManager1.isAuthenticated == true)

        // Second session: restore
        let authManager2 = AuthManager(storage: storage)
        try await authManager2.restoreSession()

        #expect(authManager2.isAuthenticated == true)
        #expect(authManager2.currentUser?.pubkey == pubkey)
    }

    @Test("AuthManager handles invalid nsec gracefully")
    func handlesInvalidNsec() async throws {
        let storage = InMemorySecureStorage()
        let authManager = AuthManager(storage: storage)

        do {
            try await authManager.signIn(with: "invalid-nsec")
            Issue.record("Should throw error for invalid nsec")
        } catch {
            // Expected error
            #expect(authManager.isAuthenticated == false)
            #expect(authManager.currentUser == nil)
        }
    }

    @Test("AuthManager handles missing session gracefully")
    func handlesMissingSession() async throws {
        let storage = InMemorySecureStorage()
        let authManager = AuthManager(storage: storage)

        // Try to restore when no session exists
        try await authManager.restoreSession()

        #expect(authManager.isAuthenticated == false)
        #expect(authManager.currentUser == nil)
    }

    @Test("AuthManager provides signer for authenticated user")
    func providesSigner() async throws {
        let storage = InMemorySecureStorage()
        let authManager = AuthManager(storage: storage)

        let signer = try NDKPrivateKeySigner.generate()
        let nsec = try signer.nsec

        try await authManager.signIn(with: nsec)

        #expect(authManager.signer != nil)
        #expect(try await authManager.signer?.pubkey == authManager.currentUser?.pubkey)
    }

    @Test("AuthManager clears signer on sign out")
    func clearsSignerOnSignOut() async throws {
        let storage = InMemorySecureStorage()
        let authManager = AuthManager(storage: storage)

        let signer = try NDKPrivateKeySigner.generate()
        let nsec = try signer.nsec

        try await authManager.signIn(with: nsec)
        #expect(authManager.signer != nil)

        try await authManager.signOut()
        #expect(authManager.signer == nil)
    }
}
