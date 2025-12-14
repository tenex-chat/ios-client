//
// LoginViewModel.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation
import NDKSwiftCore
import Observation
import OSLog

// MARK: - LoginViewModel

/// View model for the login screen
@MainActor
@Observable
public final class LoginViewModel {
    // MARK: Lifecycle

    /// Initialize the login view model
    /// - Parameter authManager: The auth manager to use for sign in
    public init(authManager: NDKAuthManager) {
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

        // Sanitize input - remove all whitespace and control characters
        // macOS clipboard can include invisible characters when pasting
        let sanitized = nsecInput
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .filter { !$0.isWhitespace && !$0.isNewline }

        Logger().debug("Login attempt with nsec length: \(sanitized.count), prefix: \(String(sanitized.prefix(5)))")

        // Attempt sign in
        do {
            let signer = try NDKPrivateKeySigner(nsec: sanitized)
            _ = try await authManager.addSession(signer)
            // Sign in successful, error message stays nil
        } catch {
            Logger().error("Login failed: \(error.localizedDescription)")
            // Sign in failed, set error message
            errorMessage = "Invalid private key. Please check your nsec and try again."
        }
    }

    // MARK: Private

    private let authManager: NDKAuthManager
}
