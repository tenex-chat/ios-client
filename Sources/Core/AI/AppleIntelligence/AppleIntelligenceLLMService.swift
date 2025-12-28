//
// AppleIntelligenceLLMService.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation
#if canImport(FoundationModels)
    import FoundationModels
#endif

// MARK: - AppleIntelligenceError

/// Errors specific to Apple Intelligence LLM operations
public enum AppleIntelligenceError: Error, LocalizedError, Sendable {
    case notAvailable(AppleIntelligenceUnavailableReason)
    case generationFailed(String)
    case sessionError(String)
    case unsupportedOnCurrentOS

    // MARK: Public

    public var errorDescription: String? {
        switch self {
        case .notAvailable(let reason):
            switch reason {
            case .deviceNotEligible:
                return "This device does not support Apple Intelligence"
            case .appleIntelligenceNotEnabled:
                return "Apple Intelligence is not enabled. Enable it in Settings > Apple Intelligence & Siri"
            case .modelNotReady:
                return "Apple Intelligence model is still downloading or initializing"
            case .unsupportedOS:
                return "Apple Intelligence requires iOS 26 or later"
            case .unknownReason:
                return "Apple Intelligence is currently unavailable"
            }
        case .generationFailed(let message):
            return "Generation failed: \(message)"
        case .sessionError(let message):
            return "Session error: \(message)"
        case .unsupportedOnCurrentOS:
            return "Apple Intelligence LLM requires iOS 26 or later"
        }
    }
}

// MARK: - AppleIntelligenceGenerationOptions

/// Options for controlling Apple Intelligence text generation
public struct AppleIntelligenceGenerationOptions: Sendable {
    // MARK: Lifecycle

    public init(
        temperature: Double = 0.7,
        maxTokens: Int? = nil
    ) {
        self.temperature = max(0.0, min(2.0, temperature))
        self.maxTokens = maxTokens
    }

    // MARK: Public

    /// Temperature for generation (0.0 - 2.0). Lower values are more deterministic.
    public let temperature: Double

    /// Maximum number of tokens to generate. Nil for no limit.
    public let maxTokens: Int?
}

// MARK: - AppleIntelligenceResponse

/// Response from Apple Intelligence generation
public struct AppleIntelligenceResponse: Sendable {
    /// The generated text content
    public let content: String

    /// Duration of generation in seconds
    public let duration: TimeInterval
}

// MARK: - AppleIntelligenceLLMService

/// Protocol for Apple Intelligence LLM operations
public protocol AppleIntelligenceLLMService: Sendable {
    /// Check if Apple Intelligence is available for use
    func checkAvailability() -> AppleIntelligenceAvailability

    /// Generate a response to a prompt
    /// - Parameters:
    ///   - prompt: The input prompt
    ///   - instructions: Optional system instructions
    ///   - options: Generation options
    /// - Returns: The generated response
    func generate(
        prompt: String,
        instructions: String?,
        options: AppleIntelligenceGenerationOptions
    ) async throws -> AppleIntelligenceResponse

    /// Stream a response to a prompt
    /// - Parameters:
    ///   - prompt: The input prompt
    ///   - instructions: Optional system instructions
    ///   - options: Generation options
    /// - Returns: An async stream of partial response text
    func streamGenerate(
        prompt: String,
        instructions: String?,
        options: AppleIntelligenceGenerationOptions
    ) async throws -> AsyncThrowingStream<String, Error>

    /// Prewarm the model for faster first response
    func prewarm() async throws
}

// MARK: - AppleIntelligenceLLMServiceImpl

/// Implementation of Apple Intelligence LLM service using Foundation Models framework
@available(iOS 26.0, macOS 26.0, *)
public actor AppleIntelligenceLLMServiceImpl: AppleIntelligenceLLMService {
    // MARK: Lifecycle

    public init(capabilityDetector: AICapabilityDetector = RuntimeAICapabilityDetector()) {
        self.capabilityDetector = capabilityDetector
    }

    // MARK: Public

    public nonisolated func checkAvailability() -> AppleIntelligenceAvailability {
        capabilityDetector.getAppleIntelligenceAvailability()
    }

    #if canImport(FoundationModels)
        public func generate(
            prompt: String,
            instructions: String?,
            options: AppleIntelligenceGenerationOptions
        ) async throws -> AppleIntelligenceResponse {
            // Check availability
            let availability = checkAvailability()
            guard availability == .available else {
                if case .unavailable(let reason) = availability {
                    throw AppleIntelligenceError.notAvailable(reason)
                }
                throw AppleIntelligenceError.notAvailable(.unknownReason)
            }

            // Create or reuse session
            let session = try await getOrCreateSession(instructions: instructions)

            // Configure generation options
            let genOptions = GenerationOptions(
                temperature: options.temperature,
                maximumResponseTokens: options.maxTokens
            )

            // Generate response
            let startTime = Date()
            let response = try await session.respond(to: prompt, options: genOptions)
            let duration = Date().timeIntervalSince(startTime)

            return AppleIntelligenceResponse(
                content: response.content,
                duration: duration
            )
        }

        public func streamGenerate(
            prompt: String,
            instructions: String?,
            options: AppleIntelligenceGenerationOptions
        ) async throws -> AsyncThrowingStream<String, Error> {
            // Check availability
            let availability = checkAvailability()
            guard availability == .available else {
                if case .unavailable(let reason) = availability {
                    throw AppleIntelligenceError.notAvailable(reason)
                }
                throw AppleIntelligenceError.notAvailable(.unknownReason)
            }

            // Create session
            let session = try await getOrCreateSession(instructions: instructions)

            // Configure generation options
            let genOptions = GenerationOptions(
                temperature: options.temperature,
                maximumResponseTokens: options.maxTokens
            )

            // Return streaming response
            return AsyncThrowingStream { continuation in
                Task {
                    do {
                        let stream = session.streamResponse(to: prompt, options: genOptions)
                        for try await partialResponse in stream {
                            continuation.yield(partialResponse.content)
                        }
                        continuation.finish()
                    } catch {
                        continuation.finish(throwing: AppleIntelligenceError.generationFailed(error.localizedDescription))
                    }
                }
            }
        }

        public func prewarm() async throws {
            let availability = checkAvailability()
            guard availability == .available else {
                if case .unavailable(let reason) = availability {
                    throw AppleIntelligenceError.notAvailable(reason)
                }
                throw AppleIntelligenceError.notAvailable(.unknownReason)
            }

            let session = try await getOrCreateSession(instructions: nil)
            try await session.prewarm()
        }
    #else
        public func generate(
            prompt _: String,
            instructions _: String?,
            options _: AppleIntelligenceGenerationOptions
        ) async throws -> AppleIntelligenceResponse {
            throw AppleIntelligenceError.unsupportedOnCurrentOS
        }

        public func streamGenerate(
            prompt _: String,
            instructions _: String?,
            options _: AppleIntelligenceGenerationOptions
        ) async throws -> AsyncThrowingStream<String, Error> {
            throw AppleIntelligenceError.unsupportedOnCurrentOS
        }

        public func prewarm() async throws {
            throw AppleIntelligenceError.unsupportedOnCurrentOS
        }
    #endif

    // MARK: Private

    private let capabilityDetector: AICapabilityDetector
    private var cachedInstructions: String?

    #if canImport(FoundationModels)
        private var currentSession: LanguageModelSession?

        private func getOrCreateSession(instructions: String?) async throws -> LanguageModelSession {
            // Reuse existing session if instructions haven't changed
            if let session = currentSession, instructions == cachedInstructions {
                return session
            }

            // Create new session
            let session: LanguageModelSession
            if let instructions {
                session = LanguageModelSession {
                    instructions
                }
            } else {
                session = LanguageModelSession()
            }

            currentSession = session
            cachedInstructions = instructions
            return session
        }
    #endif
}

// MARK: - Fallback Service for older iOS versions

/// Fallback implementation that throws unsupported errors for iOS < 26
public final class AppleIntelligenceLLMServiceFallback: AppleIntelligenceLLMService, @unchecked Sendable {
    // MARK: Lifecycle

    public init() {}

    // MARK: Public

    public func checkAvailability() -> AppleIntelligenceAvailability {
        .unavailable(.unsupportedOS)
    }

    public func generate(
        prompt _: String,
        instructions _: String?,
        options _: AppleIntelligenceGenerationOptions
    ) async throws -> AppleIntelligenceResponse {
        throw AppleIntelligenceError.unsupportedOnCurrentOS
    }

    public func streamGenerate(
        prompt _: String,
        instructions _: String?,
        options _: AppleIntelligenceGenerationOptions
    ) async throws -> AsyncThrowingStream<String, Error> {
        throw AppleIntelligenceError.unsupportedOnCurrentOS
    }

    public func prewarm() async throws {
        throw AppleIntelligenceError.unsupportedOnCurrentOS
    }
}

// MARK: - Factory

/// Factory for creating the appropriate Apple Intelligence service based on OS version
public enum AppleIntelligenceLLMServiceFactory {
    /// Create an Apple Intelligence LLM service appropriate for the current OS
    public static func create(
        capabilityDetector: AICapabilityDetector = RuntimeAICapabilityDetector()
    ) -> any AppleIntelligenceLLMService {
        if #available(iOS 26.0, macOS 26.0, *) {
            return AppleIntelligenceLLMServiceImpl(capabilityDetector: capabilityDetector)
        } else {
            return AppleIntelligenceLLMServiceFallback()
        }
    }
}
