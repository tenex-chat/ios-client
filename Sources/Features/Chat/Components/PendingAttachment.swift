//
// PendingAttachment.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation
import NDKSwiftCore
import SwiftUI
import TENEXCore

#if os(iOS)
import UIKit
#endif

// MARK: - PendingAttachment

/// Represents an image attachment pending upload or already uploaded
@MainActor
@Observable
public final class PendingAttachment: Identifiable, Equatable {
    public static func == (lhs: PendingAttachment, rhs: PendingAttachment) -> Bool {
        lhs.id == rhs.id
    }

    public let id: UUID
    public let imageData: Data
    public let thumbnail: Image
    public let mimeType: String

    public private(set) var uploadState: UploadState = .pending
    public private(set) var uploadProgress: Double = 0
    public private(set) var uploadResult: BlossomUploadResult?
    public private(set) var error: Error?

    public enum UploadState: Equatable {
        case pending
        case uploading
        case completed
        case failed
    }

    public init(imageData: Data, mimeType: String, thumbnail: Image) {
        self.id = UUID()
        self.imageData = imageData
        self.mimeType = mimeType
        self.thumbnail = thumbnail
    }

    #if os(iOS)
    /// Create from UIImage
    public convenience init?(image: UIImage) {
        guard let data = image.jpegData(compressionQuality: 0.8) else {
            return nil
        }
        let thumbnail = Image(uiImage: image)
        self.init(imageData: data, mimeType: "image/jpeg", thumbnail: thumbnail)
    }
    #endif

    /// Upload the attachment to a Blossom server
    public func upload(ndk: NDK, serverURL: String = BlossomClient.defaultServerURL) async {
        guard uploadState == .pending || uploadState == .failed else {
            return
        }

        uploadState = .uploading
        uploadProgress = 0
        error = nil

        do {
            let blossomClient = BlossomClient(serverURL: serverURL)
            let stream = blossomClient.upload(
                data: imageData,
                mimeType: mimeType,
                ndk: ndk
            )

            for try await event in stream {
                switch event {
                case let .progress(progress):
                    uploadProgress = progress.fractionCompleted
                case let .completed(result):
                    uploadResult = result
                    uploadState = .completed
                    uploadProgress = 1.0
                }
            }
        } catch {
            self.error = error
            uploadState = .failed
        }
    }

    /// Retry a failed upload
    public func retry(ndk: NDK, serverURL: String = BlossomClient.defaultServerURL) async {
        guard uploadState == .failed else {
            return
        }
        await upload(ndk: ndk, serverURL: serverURL)
    }
}
