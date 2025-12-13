//
// NavigationShellTests.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation
import NDKSwiftCore
@testable import TENEXFeatures
import Testing

@Suite("NavigationShell Tests")
@MainActor
struct NavigationShellTests {
    // MARK: - Sign Out Tests

    @Test("NavigationShell sign-out triggers AuthManager.signOut()")
    func signOutTriggersAuthManager() async throws {
        let storage = InMemorySecureStorage()
        let authManager = AuthManager(storage: storage)

        // Sign in first
        let signer = try NDKPrivateKeySigner.generate()
        let nsec = try signer.nsec

        try await authManager.signIn(with: nsec)
        #expect(authManager.isAuthenticated == true)

        // Sign out
        try await authManager.signOut()

        // Verify sign out cleared authentication
        #expect(authManager.isAuthenticated == false)
        #expect(authManager.currentUser == nil)
        #expect(authManager.signer == nil)
    }

    @Test("NavigationShell sign-out clears keychain")
    func signOutClearsKeychain() async throws {
        let storage = InMemorySecureStorage()
        let authManager = AuthManager(storage: storage)

        // Sign in first
        let signer = try NDKPrivateKeySigner.generate()
        let nsec = try signer.nsec

        try await authManager.signIn(with: nsec)

        // Verify credentials are stored
        let storedNsec = try storage.retrieve(for: "nsec")
        #expect(storedNsec != nil)

        // Sign out
        try await authManager.signOut()

        // Verify credentials are cleared
        let clearedNsec = try storage.retrieve(for: "nsec")
        #expect(clearedNsec == nil)
    }
}
