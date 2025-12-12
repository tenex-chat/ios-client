//
// LoginViewModel.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation
import Observation

// MARK: - LoginViewModel

/// View model for the login screen
@MainActor
@Observable
public final class LoginViewModel {
    // MARK: Lifecycle

    /// Initialize the login view model
    /// - Parameter authManager: The auth manager to use for sign in
    public init(authManager: AuthManager) {
        self.authManager = authManager
    }

    // MARK: Public

    /// The nsec input from the user
    public var nsecInput = ""

    /// Whether a sign in operation is in progress
    public var isLoading = false

    /// The current error message, if any
    public var errorMessage: String?

    /// Whether the current input is valid
    public var isValidInput: Bool {
        let trimmed = nsecInput.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed.hasPrefix("nsec1")
    }

    /// Attempt to sign in with the current nsec input
    public func signIn() async {
        // Clear previous error
        errorMessage = nil

        // Start loading
        isLoading = true

        defer {
            // Always stop loading when done
            isLoading = false
        }

        // Trim whitespace from input
        let trimmed = nsecInput.trimmingCharacters(in: .whitespacesAndNewlines)

        // Attempt sign in
        do {
            try await authManager.signIn(with: trimmed)
            // Sign in successful, error message stays nil
        } catch {
            // Sign in failed, set error message
            errorMessage = "Invalid private key. Please check your nsec and try again."
        }
    }

    // MARK: Private

    private let authManager: AuthManager
}
