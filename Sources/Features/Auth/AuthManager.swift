//
// AuthManager.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation
import NDKSwiftCore
import Observation

// MARK: - AuthUser

/// User authentication information
public struct AuthUser: Sendable {
    // MARK: Lifecycle

    public init(pubkey: String, npub: String) {
        self.pubkey = pubkey
        self.npub = npub
    }

    // MARK: Public

    public let pubkey: String
    public let npub: String
}

// MARK: - AuthManager

/// Manages user authentication and session persistence
@MainActor
@Observable
public final class AuthManager {
    // MARK: Lifecycle

    // MARK: - Initialization

    /// Initialize the auth manager with secure storage
    /// - Parameters:
    ///   - storage: Secure storage instance for credential persistence (defaults to KeychainStorage)
    ///   - biometricAuthenticator: Biometric authenticator instance (defaults to BiometricAuthenticator)
    public init(
        storage: SecureStorage = KeychainStorage(),
        biometricAuthenticator: BiometricAuthenticator = BiometricAuthenticator()
    ) {
        self.storage = storage
        self.biometricAuthenticator = biometricAuthenticator

        // Restore biometric preference from storage
        isBiometricEnabled = (try? storage.retrieve(for: StorageKey.biometricEnabled)) == "true"
    }

    // MARK: Public

    /// Whether the user is currently authenticated
    public private(set) var isAuthenticated = false

    /// The currently authenticated user
    public private(set) var currentUser: AuthUser?

    /// The signer for the authenticated user
    public private(set) var signer: NDKPrivateKeySigner?

    /// Whether biometric authentication is enabled for this user
    public private(set) var isBiometricEnabled = false

    // MARK: - Sign In

    /// Sign in with a private key (nsec)
    /// - Parameter nsec: The user's private key in nsec format
    /// - Throws: Error if the nsec is invalid or storage fails
    public func signIn(with nsec: String) async throws {
        // Create signer from nsec
        let keySigner = try NDKPrivateKeySigner(nsec: nsec)

        // Get pubkey and npub
        let pubkey = try await keySigner.pubkey
        let npub = try keySigner.npub

        // Store credentials in keychain
        try storage.save(nsec, for: StorageKey.nsec)
        try storage.save(pubkey, for: StorageKey.pubkey)
        try storage.save(npub, for: StorageKey.npub)

        // Update state
        signer = keySigner
        currentUser = AuthUser(pubkey: pubkey, npub: npub)
        isAuthenticated = true
    }

    // MARK: - Sign Out

    /// Sign out and clear stored credentials
    /// - Throws: Error if keychain operations fail
    public func signOut() async throws {
        // Clear keychain
        try storage.delete(for: StorageKey.nsec)
        try storage.delete(for: StorageKey.pubkey)
        try storage.delete(for: StorageKey.npub)
        try storage.delete(for: StorageKey.biometricEnabled)

        // Clear state
        signer = nil
        currentUser = nil
        isAuthenticated = false
        isBiometricEnabled = false
    }

    // MARK: - Session Restoration

    /// Restore session from stored credentials
    /// - Throws: Error if restoration fails or biometric authentication fails
    public func restoreSession() async throws {
        // Try to retrieve stored credentials
        guard let storedNsec = try storage.retrieve(for: StorageKey.nsec),
              let storedPubkey = try storage.retrieve(for: StorageKey.pubkey),
              let storedNpub = try storage.retrieve(for: StorageKey.npub)
        else {
            // No stored session
            isAuthenticated = false
            currentUser = nil
            signer = nil
            isBiometricEnabled = false
            return
        }

        // Check if biometric authentication is enabled
        let biometricEnabled = (try? storage.retrieve(for: StorageKey.biometricEnabled)) == "true"
        isBiometricEnabled = biometricEnabled

        // If biometric is enabled, require authentication
        if biometricEnabled {
            _ = try await biometricAuthenticator.authenticate(reason: "Authenticate to restore your session")
        }

        // Create signer from stored nsec
        do {
            let keySigner = try NDKPrivateKeySigner(nsec: storedNsec)

            // Verify pubkey matches
            let pubkey = try await keySigner.pubkey
            guard pubkey == storedPubkey else {
                // Pubkey mismatch, clear invalid session
                try await signOut()
                return
            }

            // Restore state
            signer = keySigner
            currentUser = AuthUser(pubkey: storedPubkey, npub: storedNpub)
            isAuthenticated = true
        } catch {
            // Invalid stored credentials, clear them
            try await signOut()
            throw error
        }
    }

    // MARK: - Biometric Authentication

    /// Enable biometric authentication for this session
    /// - Throws: Error if not authenticated or biometric setup fails
    public func enableBiometric() async throws {
        // Ensure user is authenticated
        guard isAuthenticated else {
            throw AuthError.notAuthenticated
        }

        // Verify biometric is available
        guard biometricAuthenticator.isBiometricAvailable else {
            throw BiometricError.notAvailable
        }

        // Authenticate to confirm user consent
        _ = try await biometricAuthenticator.authenticate(reason: "Enable biometric authentication")

        // Store preference
        try storage.save("true", for: StorageKey.biometricEnabled)
        isBiometricEnabled = true
    }

    /// Disable biometric authentication
    /// - Throws: Error if storage operations fail
    public func disableBiometric() async throws {
        // Clear preference
        try storage.delete(for: StorageKey.biometricEnabled)
        isBiometricEnabled = false
    }

    // MARK: Private

    // MARK: - Keys

    private enum StorageKey {
        static let nsec = "nsec"
        static let pubkey = "pubkey"
        static let npub = "npub"
        static let biometricEnabled = "biometric_enabled"
    }

    /// Secure storage for credentials
    private let storage: SecureStorage

    /// Biometric authenticator
    private let biometricAuthenticator: BiometricAuthenticator
}

// MARK: - AuthError

/// Authentication errors
public enum AuthError: Error, LocalizedError {
    case notAuthenticated

    // MARK: Public

    public var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            "User is not authenticated"
        }
    }
}
