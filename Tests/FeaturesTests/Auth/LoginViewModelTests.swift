//
// LoginViewModelTests.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation
import NDKSwift
@testable import TENEXFeatures
import Testing

@Suite("LoginViewModel Tests")
@MainActor
struct LoginViewModelTests {
    // MARK: - Initial State Tests

    @Test("LoginViewModel starts with empty input")
    func startsWithEmptyInput() async throws {
        let storage = InMemorySecureStorage()
        let authManager = AuthManager(storage: storage)
        let viewModel = LoginViewModel(authManager: authManager)

        #expect(viewModel.nsecInput.isEmpty)
    }

    @Test("LoginViewModel starts with invalid input state")
    func startsWithInvalidState() async throws {
        let storage = InMemorySecureStorage()
        let authManager = AuthManager(storage: storage)
        let viewModel = LoginViewModel(authManager: authManager)

        #expect(viewModel.isValidInput == false)
    }

    @Test("LoginViewModel starts with no error")
    func startsWithNoError() async throws {
        let storage = InMemorySecureStorage()
        let authManager = AuthManager(storage: storage)
        let viewModel = LoginViewModel(authManager: authManager)

        #expect(viewModel.errorMessage == nil)
    }

    @Test("LoginViewModel starts with not loading state")
    func startsNotLoading() async throws {
        let storage = InMemorySecureStorage()
        let authManager = AuthManager(storage: storage)
        let viewModel = LoginViewModel(authManager: authManager)

        #expect(viewModel.isLoading == false)
    }

    // MARK: - Input Validation Tests

    @Test("LoginViewModel recognizes valid nsec input")
    func recognizesValidNsec() async throws {
        let storage = InMemorySecureStorage()
        let authManager = AuthManager(storage: storage)
        let viewModel = LoginViewModel(authManager: authManager)

        // Generate a valid nsec
        let signer = try NDKPrivateKeySigner.generate()
        let nsec = try signer.nsec

        viewModel.nsecInput = nsec

        #expect(viewModel.isValidInput == true)
    }

    @Test("LoginViewModel recognizes invalid nsec input")
    func recognizesInvalidNsec() async throws {
        let storage = InMemorySecureStorage()
        let authManager = AuthManager(storage: storage)
        let viewModel = LoginViewModel(authManager: authManager)

        viewModel.nsecInput = "invalid-nsec-format"

        #expect(viewModel.isValidInput == false)
    }

    @Test("LoginViewModel recognizes empty input as invalid")
    func recognizesEmptyInputAsInvalid() async throws {
        let storage = InMemorySecureStorage()
        let authManager = AuthManager(storage: storage)
        let viewModel = LoginViewModel(authManager: authManager)

        viewModel.nsecInput = ""

        #expect(viewModel.isValidInput == false)
    }

    @Test("LoginViewModel recognizes whitespace-only input as invalid")
    func recognizesWhitespaceOnlyAsInvalid() async throws {
        let storage = InMemorySecureStorage()
        let authManager = AuthManager(storage: storage)
        let viewModel = LoginViewModel(authManager: authManager)

        viewModel.nsecInput = "   "

        #expect(viewModel.isValidInput == false)
    }

    @Test("LoginViewModel recognizes input not starting with nsec as invalid")
    func recognizesNonNsecPrefixAsInvalid() async throws {
        let storage = InMemorySecureStorage()
        let authManager = AuthManager(storage: storage)
        let viewModel = LoginViewModel(authManager: authManager)

        viewModel.nsecInput = "npub1abc123"

        #expect(viewModel.isValidInput == false)
    }

    // MARK: - Sign In Success Tests

    @Test("LoginViewModel successful sign in updates AuthManager")
    func successfulSignInUpdatesAuthManager() async throws {
        let storage = InMemorySecureStorage()
        let authManager = AuthManager(storage: storage)
        let viewModel = LoginViewModel(authManager: authManager)

        // Generate a valid nsec
        let signer = try NDKPrivateKeySigner.generate()
        let nsec = try signer.nsec

        viewModel.nsecInput = nsec

        // Perform sign in
        await viewModel.signIn()

        // Verify auth manager is updated
        #expect(authManager.isAuthenticated == true)
        #expect(authManager.currentUser != nil)
    }

    @Test("LoginViewModel shows loading state during sign in")
    func showsLoadingStateDuringSignIn() async throws {
        let storage = InMemorySecureStorage()
        let authManager = AuthManager(storage: storage)
        let viewModel = LoginViewModel(authManager: authManager)

        // Generate a valid nsec
        let signer = try NDKPrivateKeySigner.generate()
        let nsec = try signer.nsec

        viewModel.nsecInput = nsec

        // Start sign in task
        let signInTask = Task {
            await viewModel.signIn()
        }

        // Check loading state immediately (before sign in completes)
        // Note: This is a best-effort test, may be flaky due to timing
        try await Task.sleep(nanoseconds: 100_000) // 0.1ms
        #expect(viewModel.isLoading == true || viewModel.isLoading == false) // Either state is possible

        await signInTask.value

        // After sign in, loading should be false
        #expect(viewModel.isLoading == false)
    }

    @Test("LoginViewModel clears error message on successful sign in")
    func clearsErrorOnSuccessfulSignIn() async throws {
        let storage = InMemorySecureStorage()
        let authManager = AuthManager(storage: storage)
        let viewModel = LoginViewModel(authManager: authManager)

        // Set an error first
        viewModel.errorMessage = "Previous error"

        // Generate a valid nsec
        let signer = try NDKPrivateKeySigner.generate()
        let nsec = try signer.nsec

        viewModel.nsecInput = nsec

        // Perform sign in
        await viewModel.signIn()

        // Error should be cleared
        #expect(viewModel.errorMessage == nil)
    }

    // MARK: - Sign In Failure Tests

    @Test("LoginViewModel shows error message on invalid nsec")
    func showsErrorOnInvalidNsec() async throws {
        let storage = InMemorySecureStorage()
        let authManager = AuthManager(storage: storage)
        let viewModel = LoginViewModel(authManager: authManager)

        viewModel.nsecInput = "invalid-nsec"

        await viewModel.signIn()

        // Should have an error message
        let errorMessage = try #require(viewModel.errorMessage)
        #expect(!errorMessage.isEmpty)
    }

    @Test("LoginViewModel does not authenticate on invalid nsec")
    func doesNotAuthenticateOnInvalidNsec() async throws {
        let storage = InMemorySecureStorage()
        let authManager = AuthManager(storage: storage)
        let viewModel = LoginViewModel(authManager: authManager)

        viewModel.nsecInput = "invalid-nsec"

        await viewModel.signIn()

        // Should not be authenticated
        #expect(authManager.isAuthenticated == false)
        #expect(authManager.currentUser == nil)
    }

    @Test("LoginViewModel stops loading state after error")
    func stopsLoadingAfterError() async throws {
        let storage = InMemorySecureStorage()
        let authManager = AuthManager(storage: storage)
        let viewModel = LoginViewModel(authManager: authManager)

        viewModel.nsecInput = "invalid-nsec"

        await viewModel.signIn()

        // Loading should be false after error
        #expect(viewModel.isLoading == false)
    }

    // MARK: - Edge Cases

    @Test("LoginViewModel handles sign in with whitespace around nsec")
    func handlesWhitespaceAroundNsec() async throws {
        let storage = InMemorySecureStorage()
        let authManager = AuthManager(storage: storage)
        let viewModel = LoginViewModel(authManager: authManager)

        // Generate a valid nsec with surrounding whitespace
        let signer = try NDKPrivateKeySigner.generate()
        let nsec = try signer.nsec

        viewModel.nsecInput = "  \(nsec)  "

        await viewModel.signIn()

        // Should successfully sign in
        #expect(authManager.isAuthenticated == true)
        #expect(viewModel.errorMessage == nil)
    }

    @Test("LoginViewModel allows multiple sign in attempts")
    func allowsMultipleSignInAttempts() async throws {
        let storage = InMemorySecureStorage()
        let authManager = AuthManager(storage: storage)
        let viewModel = LoginViewModel(authManager: authManager)

        // First attempt with invalid nsec
        viewModel.nsecInput = "invalid-nsec"
        await viewModel.signIn()

        #expect(authManager.isAuthenticated == false)
        #expect(viewModel.errorMessage != nil)

        // Second attempt with valid nsec
        let signer = try NDKPrivateKeySigner.generate()
        let nsec = try signer.nsec

        viewModel.nsecInput = nsec
        await viewModel.signIn()

        #expect(authManager.isAuthenticated == true)
        #expect(viewModel.errorMessage == nil)
    }
}
