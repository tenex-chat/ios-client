//
// BlossomClient.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import CryptoKit
import Foundation
import NDKSwiftCore

// MARK: - BlossomError

/// Errors specific to Blossom operations
public enum BlossomError: LocalizedError {
    case uploadFailed(String)
    case invalidServerURL
    case hashMismatch(expected: String, actual: String)
    case noSignerAvailable
    case invalidResponse

    public var errorDescription: String? {
        switch self {
        case let .uploadFailed(reason):
            "Upload failed: \(reason)"
        case .invalidServerURL:
            "Invalid Blossom server URL"
        case let .hashMismatch(expected, actual):
            "SHA256 mismatch: expected \(expected), got \(actual)"
        case .noSignerAvailable:
            "No signer available for authentication"
        case .invalidResponse:
            "Invalid response from Blossom server"
        }
    }
}

// MARK: - BlossomUploadResult

/// Result of a successful Blossom upload
public struct BlossomUploadResult: Sendable {
    public let url: String
    public let sha256: String
    public let size: Int64
    public let mimeType: String?

    public init(url: String, sha256: String, size: Int64, mimeType: String?) {
        self.url = url
        self.sha256 = sha256
        self.size = size
        self.mimeType = mimeType
    }
}

// MARK: - BlossomUploadProgress

/// Progress update during Blossom upload
public struct BlossomUploadProgress: Sendable {
    public let bytesSent: Int64
    public let totalBytes: Int64

    public var fractionCompleted: Double {
        guard totalBytes > 0 else {
            return 0
        }
        return Double(bytesSent) / Double(totalBytes)
    }

    public init(bytesSent: Int64, totalBytes: Int64) {
        self.bytesSent = bytesSent
        self.totalBytes = totalBytes
    }
}

// MARK: - BlossomUploadEvent

/// Events emitted during upload
public enum BlossomUploadEvent: Sendable {
    case progress(BlossomUploadProgress)
    case completed(BlossomUploadResult)
}

// MARK: - BlossomClient

/// HTTP-based Blossom upload client
/// Implements BUD-02 (Blob Upload & Discovery) protocol
public final class BlossomClient: NSObject, Sendable {
    // MARK: - Constants

    /// Default Blossom server URL
    public static let defaultServerURL = "https://blossom.primal.net"

    // MARK: - Properties

    private let serverURL: String

    // MARK: - Initialization

    public init(serverURL: String = BlossomClient.defaultServerURL) {
        self.serverURL = serverURL
        super.init()
    }

    // MARK: - Public Methods

    /// Upload data to the Blossom server with progress tracking
    /// - Parameters:
    ///   - data: The binary data to upload
    ///   - mimeType: MIME type of the data
    ///   - ndk: NDK instance for signing the auth event
    /// - Returns: AsyncThrowingStream that yields progress events and completes with the result
    public func upload(
        data: Data,
        mimeType: String,
        ndk: NDK
    ) -> AsyncThrowingStream<BlossomUploadEvent, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let result = try await self.performUpload(
                        data: data,
                        mimeType: mimeType,
                        ndk: ndk
                    ) { progress in
                        continuation.yield(.progress(progress))
                    }
                    continuation.yield(.completed(result))
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    /// Upload data without progress tracking
    /// - Parameters:
    ///   - data: The binary data to upload
    ///   - mimeType: MIME type of the data
    ///   - ndk: NDK instance for signing the auth event
    /// - Returns: The upload result
    public func uploadWithoutProgress(
        data: Data,
        mimeType: String,
        ndk: NDK
    ) async throws -> BlossomUploadResult {
        try await performUpload(data: data, mimeType: mimeType, ndk: ndk, onProgress: nil)
    }

    // MARK: - Private Methods

    private func performUpload(
        data: Data,
        mimeType: String,
        ndk: NDK,
        onProgress: (@Sendable (BlossomUploadProgress) -> Void)?
    ) async throws -> BlossomUploadResult {
        // Compute SHA256 hash
        let sha256 = Self.sha256(of: data)

        // Create authorization header
        let authHeader = try await createAuthHeader(sha256: sha256, ndk: ndk)

        // Build the upload URL
        guard let baseURL = URL(string: serverURL) else {
            throw BlossomError.invalidServerURL
        }
        let uploadURL = baseURL.appendingPathComponent("upload")

        // Create the request
        var request = URLRequest(url: uploadURL)
        request.httpMethod = "PUT"
        request.setValue(mimeType, forHTTPHeaderField: "Content-Type")
        request.setValue(authHeader, forHTTPHeaderField: "Authorization")

        // Perform upload with progress tracking
        let (responseData, response) = try await uploadWithProgress(
            request: request,
            data: data,
            onProgress: onProgress
        )

        // Validate response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw BlossomError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200, 201:
            // Parse response
            let decoder = JSONDecoder()
            let uploadResponse = try decoder.decode(BlossomServerResponse.self, from: responseData)

            // Verify SHA256 matches
            guard uploadResponse.sha256 == sha256 else {
                throw BlossomError.hashMismatch(expected: sha256, actual: uploadResponse.sha256)
            }

            return BlossomUploadResult(
                url: uploadResponse.url,
                sha256: uploadResponse.sha256,
                size: uploadResponse.size,
                mimeType: uploadResponse.type
            )

        case 401:
            throw BlossomError.uploadFailed("Unauthorized - authentication failed")

        case 413:
            throw BlossomError.uploadFailed("File too large")

        case 415:
            throw BlossomError.uploadFailed("Unsupported media type: \(mimeType)")

        default:
            let errorMessage = String(data: responseData, encoding: .utf8) ?? "Unknown error"
            throw BlossomError.uploadFailed("Server returned \(httpResponse.statusCode): \(errorMessage)")
        }
    }

    /// Create the Nostr authorization header for Blossom upload
    /// The auth event is kind 24242 with specific tags
    private func createAuthHeader(sha256: String, ndk: NDK) async throws -> String {
        // Get expiration timestamp (1 hour from now)
        let expiration = Int(Date().timeIntervalSince1970) + 3600

        // Build the auth event (kind 24242)
        let event = try await NDKEventBuilder(ndk: ndk)
            .kind(24_242)
            .content("Upload to Blossom")
            .tag(["t", "upload"])
            .tag(["x", sha256])
            .tag(["expiration", String(expiration)])
            .build()

        // Serialize event to JSON
        let eventJSON = try event.serialize()

        // Base64 encode the JSON
        guard let jsonData = eventJSON.data(using: .utf8) else {
            throw BlossomError.uploadFailed("Failed to encode auth event")
        }
        let base64Event = jsonData.base64EncodedString()

        return "Nostr \(base64Event)"
    }

    /// Perform upload with URLSession delegate for progress tracking
    private func uploadWithProgress(
        request: URLRequest,
        data: Data,
        onProgress: (@Sendable (BlossomUploadProgress) -> Void)?
    ) async throws -> (Data, URLResponse) {
        if let onProgress {
            return try await withCheckedThrowingContinuation { continuation in
                let delegate = UploadProgressDelegate(
                    totalBytes: Int64(data.count),
                    onProgress: onProgress
                ) { result in
                    continuation.resume(with: result)
                }

                let config = URLSessionConfiguration.default
                config.timeoutIntervalForRequest = 120
                config.timeoutIntervalForResource = 600

                let session = URLSession(configuration: config, delegate: delegate, delegateQueue: nil)
                delegate.session = session

                let task = session.uploadTask(with: request, from: data)
                task.resume()
            }
        } else {
            // Simple upload without progress
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = 120
            config.timeoutIntervalForResource = 600

            let session = URLSession(configuration: config)
            defer { session.invalidateAndCancel() }

            return try await session.upload(for: request, from: data)
        }
    }

    // MARK: - Static Helpers

    /// Compute SHA256 hash of data
    public static func sha256(of data: Data) -> String {
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - BlossomServerResponse

/// Response from Blossom server after upload
private struct BlossomServerResponse: Decodable {
    let url: String
    let sha256: String
    let size: Int64
    let type: String?
}

// MARK: - UploadProgressDelegate

// swiftlint:disable line_length prefer_async_await
private final class UploadProgressDelegate: NSObject, URLSessionTaskDelegate, URLSessionDataDelegate, @unchecked Sendable {
    // swiftlint:enable line_length
    private let totalBytes: Int64
    private let onProgress: @Sendable (BlossomUploadProgress) -> Void
    private let onComplete: @Sendable (Result<(Data, URLResponse), Error>) -> Void
    private var responseData = Data()
    private var response: URLResponse?
    var session: URLSession?

    init(
        totalBytes: Int64,
        onProgress: @escaping @Sendable (BlossomUploadProgress) -> Void,
        onComplete: @escaping @Sendable (Result<(Data, URLResponse), Error>) -> Void
    ) {
        self.totalBytes = totalBytes
        self.onProgress = onProgress
        self.onComplete = onComplete
    }

    func urlSession(
        _: URLSession,
        task _: URLSessionTask,
        didSendBodyData _: Int64,
        totalBytesSent: Int64,
        totalBytesExpectedToSend: Int64
    ) {
        let progress = BlossomUploadProgress(
            bytesSent: totalBytesSent,
            totalBytes: totalBytesExpectedToSend > 0 ? totalBytesExpectedToSend : totalBytes
        )
        onProgress(progress)
    }

    func urlSession(
        _: URLSession,
        dataTask _: URLSessionDataTask,
        didReceive response: URLResponse,
        completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
    ) {
        self.response = response
        completionHandler(.allow)
    }

    func urlSession(_: URLSession, dataTask _: URLSessionDataTask, didReceive data: Data) {
        responseData.append(data)
    }

    func urlSession(_: URLSession, task _: URLSessionTask, didCompleteWithError error: Error?) {
        defer { session?.invalidateAndCancel() }

        if let error {
            onComplete(.failure(error))
        } else if let response {
            onComplete(.success((responseData, response)))
        } else {
            onComplete(.failure(BlossomError.invalidResponse))
        }
    }
}
// swiftlint:enable prefer_async_await
