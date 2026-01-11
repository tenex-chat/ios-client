//
// AttachmentPreviewRow.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import SwiftUI

// MARK: - AttachmentPreviewRow

/// Horizontal row showing pending attachments with upload progress
public struct AttachmentPreviewRow: View {
    public let attachments: [PendingAttachment]
    public let onRemove: (PendingAttachment) -> Void

    public init(
        attachments: [PendingAttachment],
        onRemove: @escaping (PendingAttachment) -> Void
    ) {
        self.attachments = attachments
        self.onRemove = onRemove
    }

    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(attachments) { attachment in
                    AttachmentPreviewItem(attachment: attachment) {
                        onRemove(attachment)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }
}

// MARK: - AttachmentPreviewItem

/// Single attachment preview with thumbnail, progress, and remove button
private struct AttachmentPreviewItem: View {
    let attachment: PendingAttachment
    let onRemove: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            attachmentThumbnail

            removeButton
        }
        .frame(width: 72, height: 72)
    }

    private var attachmentThumbnail: some View {
        ZStack {
            attachment.thumbnail
                .resizable()
                .scaledToFill()
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
                )

            uploadOverlay
        }
    }

    @ViewBuilder
    private var uploadOverlay: some View {
        switch attachment.uploadState {
        case .pending:
            EmptyView()

        case .uploading:
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.ultraThinMaterial)

                ProgressView(value: attachment.uploadProgress)
                    .progressViewStyle(.circular)
                    .scaleEffect(0.8)
                    .tint(.white)
            }
            .frame(width: 64, height: 64)

        case .completed:
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.green.opacity(0.3))

                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.white)
            }
            .frame(width: 64, height: 64)
            .transition(.opacity)

        case .failed:
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.red.opacity(0.5))

                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title2)
                    .foregroundStyle(.white)
            }
            .frame(width: 64, height: 64)
        }
    }

    private var removeButton: some View {
        Button(action: onRemove) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 20))
                .foregroundStyle(.white)
                .background(
                    Circle()
                        .fill(.black.opacity(0.5))
                        .frame(width: 18, height: 18)
                )
        }
        .buttonStyle(.plain)
        .offset(x: 4, y: -4)
    }
}
