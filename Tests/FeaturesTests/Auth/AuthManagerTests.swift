//
// AuthManagerTests.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation
import NDKSwiftCore
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

    // MARK: - Biometric Authentication Tests

    @Test("AuthManager enables biometric authentication")
    func enablesBiometricAuth() async throws {
        let storage = InMemorySecureStorage()
        let mockBiometric = MockBiometricContext(canEvaluate: true, biometricType: .faceID)
        let authenticator = BiometricAuthenticator(context: mockBiometric)
        let authManager = AuthManager(storage: storage, biometricAuthenticator: authenticator)

        // Sign in first
        let signer = try NDKPrivateKeySigner.generate()
        try await authManager.signIn(with: signer.nsec)

        // Enable biometric
        try await authManager.enableBiometric()

        // Verify biometric is enabled
        #expect(authManager.isBiometricEnabled == true)

        // Verify preference is stored
        let stored = try storage.retrieve(for: "biometric_enabled")
        #expect(stored == "true")
    }

    @Test("AuthManager disables biometric authentication")
    func disablesBiometricAuth() async throws {
        let storage = InMemorySecureStorage()
        let mockBiometric = MockBiometricContext(canEvaluate: true, biometricType: .faceID)
        let authenticator = BiometricAuthenticator(context: mockBiometric)
        let authManager = AuthManager(storage: storage, biometricAuthenticator: authenticator)

        // Sign in and enable biometric
        let signer = try NDKPrivateKeySigner.generate()
        try await authManager.signIn(with: signer.nsec)
        try await authManager.enableBiometric()
        #expect(authManager.isBiometricEnabled == true)

        // Disable biometric
        try await authManager.disableBiometric()

        // Verify biometric is disabled
        #expect(authManager.isBiometricEnabled == false)

        // Verify preference is cleared
        let stored = try storage.retrieve(for: "biometric_enabled")
        #expect(stored == nil)
    }

    @Test("AuthManager requires biometric auth when enabled during session restoration")
    func requiresBiometricDuringRestoration() async {
        let storage = InMemorySecureStorage()

        // First session: sign in and enable biometric (use succeeding authenticator)
        let mockBiometricSuccess = MockBiometricContext(canEvaluate: true, biometricType: .faceID, shouldSucceed: true)
        let authenticatorSuccess = BiometricAuthenticator(context: mockBiometricSuccess)
        let authManager1 = AuthManager(storage: storage, biometricAuthenticator: authenticatorSuccess)

        do {
            let signer = try NDKPrivateKeySigner.generate()
            try await authManager1.signIn(with: signer.nsec)
            try await authManager1.enableBiometric()
        } catch {
            Issue.record("Setup should not fail: \(error)")
            return
        }

        // Second session: restore should fail with failing authenticator
        let mockBiometricFail = MockBiometricContext(canEvaluate: true, biometricType: .faceID, shouldSucceed: false)
        let authenticatorFail = BiometricAuthenticator(context: mockBiometricFail)
        let authManager2 = AuthManager(storage: storage, biometricAuthenticator: authenticatorFail)

        do {
            try await authManager2.restoreSession()
            Issue.record("Should require biometric authentication")
        } catch {
            // Expected - biometric auth failed
            #expect(authManager2.isAuthenticated == false)
            #expect(authManager2.currentUser == nil)
        }
    }

    @Test("AuthManager restores session after successful biometric auth")
    func restoresSessionAfterBiometricAuth() async throws {
        let storage = InMemorySecureStorage()
        let mockBiometric = MockBiometricContext(canEvaluate: true, biometricType: .faceID, shouldSucceed: true)
        let authenticator = BiometricAuthenticator(context: mockBiometric)

        // First session: sign in and enable biometric
        let authManager1 = AuthManager(storage: storage, biometricAuthenticator: authenticator)
        let signer = try NDKPrivateKeySigner.generate()
        let pubkey = try await signer.pubkey
        try await authManager1.signIn(with: signer.nsec)
        try await authManager1.enableBiometric()

        // Second session: restore should succeed with biometric auth
        let authManager2 = AuthManager(storage: storage, biometricAuthenticator: authenticator)
        try await authManager2.restoreSession()

        #expect(authManager2.isAuthenticated == true)
        #expect(authManager2.currentUser?.pubkey == pubkey)
        #expect(authManager2.signer != nil)
    }

    @Test("AuthManager restores session normally when biometric is disabled")
    func restoresSessionWhenBiometricDisabled() async throws {
        let storage = InMemorySecureStorage()
        let mockBiometric = MockBiometricContext(canEvaluate: true, biometricType: .faceID)
        let authenticator = BiometricAuthenticator(context: mockBiometric)

        // First session: sign in without enabling biometric
        let authManager1 = AuthManager(storage: storage, biometricAuthenticator: authenticator)
        let signer = try NDKPrivateKeySigner.generate()
        let pubkey = try await signer.pubkey
        try await authManager1.signIn(with: signer.nsec)

        // Second session: restore should work without biometric
        let authManager2 = AuthManager(storage: storage, biometricAuthenticator: authenticator)
        try await authManager2.restoreSession()

        #expect(authManager2.isAuthenticated == true)
        #expect(authManager2.currentUser?.pubkey == pubkey)
    }

    @Test("AuthManager throws error when enabling biometric without authentication")
    func throwsWhenEnablingBiometricWithoutAuth() async throws {
        let storage = InMemorySecureStorage()
        let mockBiometric = MockBiometricContext(canEvaluate: true)
        let authenticator = BiometricAuthenticator(context: mockBiometric)
        let authManager = AuthManager(storage: storage, biometricAuthenticator: authenticator)

        do {
            try await authManager.enableBiometric()
            Issue.record("Should throw error when not authenticated")
        } catch {
            // Expected error
            #expect(authManager.isBiometricEnabled == false)
        }
    }

    @Test("AuthManager clears biometric preference on sign out")
    func clearsBiometricPreferenceOnSignOut() async throws {
        let storage = InMemorySecureStorage()
        let mockBiometric = MockBiometricContext(canEvaluate: true, biometricType: .faceID)
        let authenticator = BiometricAuthenticator(context: mockBiometric)
        let authManager = AuthManager(storage: storage, biometricAuthenticator: authenticator)

        // Sign in and enable biometric
        let signer = try NDKPrivateKeySigner.generate()
        try await authManager.signIn(with: signer.nsec)
        try await authManager.enableBiometric()
        #expect(authManager.isBiometricEnabled == true)

        // Sign out
        try await authManager.signOut()

        // Verify biometric preference is cleared
        #expect(authManager.isBiometricEnabled == false)
        let stored = try storage.retrieve(for: "biometric_enabled")
        #expect(stored == nil)
    }
}
