//
// BiometricAuthenticator.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation
import LocalAuthentication

// MARK: - BiometricType

/// Types of biometric authentication available
public enum BiometricType: Sendable {
    case unavailable
    case touchID
    case faceID
    case opticID
}

// MARK: - BiometricError

/// Errors that can occur during biometric authentication
public enum BiometricError: Error, LocalizedError {
    case notAvailable
    case notEnrolled
    case lockout
    case cancelled
    case failed

    // MARK: Public

    public var errorDescription: String? {
        switch self {
        case .notAvailable:
            "Biometric authentication is not available on this device"
        case .notEnrolled:
            "No biometric data is enrolled on this device"
        case .lockout:
            "Biometric authentication is locked out due to too many failed attempts"
        case .cancelled:
            "Biometric authentication was cancelled"
        case .failed:
            "Biometric authentication failed"
        }
    }
}

// MARK: - BiometricContext

/// Protocol for biometric authentication context (allows mocking in tests)
@MainActor
public protocol BiometricContext: Sendable {
    /// Check if biometric authentication can be evaluated
    func canEvaluatePolicy() -> Bool

    /// Evaluate biometric authentication policy
    /// - Parameter reason: The reason for authentication to show to the user
    /// - Returns: Whether authentication succeeded
    /// - Throws: BiometricError if authentication fails
    func evaluatePolicy(reason: String) async throws -> Bool

    /// Get the type of biometric authentication available
    func getBiometricType() -> BiometricType
}

// MARK: - LAContextWrapper

/// Wrapper around LAContext to conform to BiometricContext protocol
@MainActor
public final class LAContextWrapper: BiometricContext {
    // MARK: Lifecycle

    public init() {
        context = LAContext()
    }

    // MARK: Public

    public func canEvaluatePolicy() -> Bool {
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }

    public func evaluatePolicy(reason: String) async throws -> Bool {
        do {
            return try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            )
        } catch let error as LAError {
            throw mapLAError(error)
        }
    }

    public func getBiometricType() -> BiometricType {
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return .unavailable
        }

        switch context.biometryType {
        case .none:
            return .unavailable
        case .touchID:
            return .touchID
        case .faceID:
            return .faceID
        case .opticID:
            return .opticID
        @unknown default:
            return .unavailable
        }
    }

    // MARK: Private

    private let context: LAContext

    private func mapLAError(_ error: LAError) -> BiometricError {
        switch error.code {
        case .biometryNotAvailable:
            .notAvailable
        case .biometryNotEnrolled:
            .notEnrolled
        case .biometryLockout:
            .lockout
        case .userCancel,
             .systemCancel,
             .appCancel:
            .cancelled
        default:
            .failed
        }
    }
}

// MARK: - BiometricAuthenticator

/// Handles biometric authentication (Face ID / Touch ID)
@MainActor
public final class BiometricAuthenticator {
    // MARK: Lifecycle

    /// Initialize with a biometric context
    /// - Parameter context: The biometric context to use (defaults to LAContextWrapper)
    public init(context: BiometricContext = LAContextWrapper()) {
        self.context = context
    }

    // MARK: Public

    /// Whether biometric authentication is available on this device
    public var isBiometricAvailable: Bool {
        context.canEvaluatePolicy()
    }

    /// The type of biometric authentication available
    public var biometricType: BiometricType {
        context.getBiometricType()
    }

    /// Authenticate using biometrics
    /// - Parameter reason: The reason for authentication to show to the user
    /// - Returns: Whether authentication succeeded
    /// - Throws: BiometricError if authentication is not available or fails
    public func authenticate(reason: String) async throws -> Bool {
        guard isBiometricAvailable else {
            throw BiometricError.notAvailable
        }
        return try await context.evaluatePolicy(reason: reason)
    }

    // MARK: Private

    private let context: BiometricContext
}
