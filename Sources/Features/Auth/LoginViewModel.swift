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
        let trimmed = self.nsecInput.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed.hasPrefix("nsec1")
    }

    /// Attempt to sign in with the current nsec input
    public func signIn() async {
        // Clear previous error
        self.errorMessage = nil

        // Start loading
        self.isLoading = true

        defer {
            // Always stop loading when done
            isLoading = false
        }

        // Sanitize input - remove all whitespace and control characters
        // macOS clipboard can include invisible characters when pasting
        var sanitized = self.nsecInput
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Remove all non-printable characters and whitespace
        sanitized = String(sanitized.unicodeScalars.filter { scalar in
            // Keep only ASCII printable characters (bech32 nsec uses lowercase alphanumeric)
            scalar.value >= 32 && scalar.value < 127 && !CharacterSet.whitespacesAndNewlines.contains(scalar)
        })

        Logger().debug("""
        Login attempt:
        - Original length: \(self.nsecInput.count)
        - Sanitized length: \(sanitized.count)
        - Prefix: \(String(sanitized.prefix(10)))
        - Raw bytes: \(sanitized.utf8.map { String(format: "%02x", $0) }.joined())
        """)

        // Attempt sign in
        do {
            let signer = try NDKPrivateKeySigner(nsec: sanitized)
            _ = try await self.authManager.addSession(signer)
            // Sign in successful, error message stays nil
        } catch {
            Logger().error("Login failed: \(error)")
            Logger().error("Error type: \(type(of: error))")
            Logger().error("Error description: \(error.localizedDescription)")
            // Sign in failed, set error message
            self
                .errorMessage =
                "Invalid private key. Please check your nsec and try again.\n\n\(error.localizedDescription)"
        }
    }

    // MARK: Private

    private let authManager: NDKAuthManager
}
