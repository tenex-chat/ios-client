//
// BiometricAuthenticatorTests.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

@testable import TENEXFeatures
import Testing

// MARK: - BiometricAuthenticatorTests

@Suite("BiometricAuthenticator Tests")
struct BiometricAuthenticatorTests {
    // MARK: - Availability Tests

    @Test("BiometricAuthenticator reports availability from context")
    @MainActor
    func reportsAvailabilityFromContext() async {
        let mockContext = MockBiometricContext(canEvaluate: true)
        let authenticator = BiometricAuthenticator(context: mockContext)

        let isAvailable = authenticator.isBiometricAvailable

        #expect(isAvailable == true)
    }

    @Test("BiometricAuthenticator reports unavailable when context cannot evaluate")
    @MainActor
    func reportsUnavailableWhenContextCannotEvaluate() async {
        let mockContext = MockBiometricContext(canEvaluate: false)
        let authenticator = BiometricAuthenticator(context: mockContext)

        let isAvailable = authenticator.isBiometricAvailable

        #expect(isAvailable == false)
    }

    @Test("BiometricAuthenticator returns correct biometric type")
    @MainActor
    func returnsCorrectBiometricType() async {
        let mockContext = MockBiometricContext(canEvaluate: true, biometricType: .faceID)
        let authenticator = BiometricAuthenticator(context: mockContext)

        let type = authenticator.biometricType

        #expect(type == .faceID)
    }

    // MARK: - Authentication Tests

    @Test("BiometricAuthenticator authenticates successfully")
    @MainActor
    func authenticatesSuccessfully() async throws {
        let mockContext = MockBiometricContext(canEvaluate: true, shouldSucceed: true)
        let authenticator = BiometricAuthenticator(context: mockContext)

        let result = try await authenticator.authenticate(reason: "Test authentication")

        #expect(result == true)
    }

    @Test("BiometricAuthenticator fails authentication when denied")
    @MainActor
    func failsAuthenticationWhenDenied() async throws {
        let mockContext = MockBiometricContext(canEvaluate: true, shouldSucceed: false)
        let authenticator = BiometricAuthenticator(context: mockContext)

        let result = try await authenticator.authenticate(reason: "Test authentication")

        #expect(result == false)
    }

    @Test("BiometricAuthenticator throws when not available")
    @MainActor
    func throwsWhenNotAvailable() async {
        let mockContext = MockBiometricContext(canEvaluate: false)
        let authenticator = BiometricAuthenticator(context: mockContext)

        await #expect(throws: BiometricError.notAvailable) {
            _ = try await authenticator.authenticate(reason: "Test")
        }
    }
}

// MARK: - MockBiometricContext

/// Mock implementation for testing biometric authentication
@MainActor
final class MockBiometricContext: BiometricContext {
    // MARK: Lifecycle

    init(canEvaluate: Bool, biometricType: BiometricType = .none, shouldSucceed: Bool = true) {
        self.canEvaluate = canEvaluate
        self.biometricType = biometricType
        self.shouldSucceed = shouldSucceed
    }

    // MARK: Internal

    let canEvaluate: Bool
    let biometricType: BiometricType
    let shouldSucceed: Bool

    func canEvaluatePolicy() -> Bool {
        canEvaluate
    }

    func evaluatePolicy(reason _: String) async throws -> Bool {
        guard canEvaluate else {
            throw BiometricError.notAvailable
        }
        return shouldSucceed
    }

    func getBiometricType() -> BiometricType {
        biometricType
    }
}
