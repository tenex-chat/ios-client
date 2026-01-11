//
// DocumentRow.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import NDKSwiftCore
import NDKSwiftUI
import SwiftUI
import TENEXCore

// MARK: - DocumentRow

/// Row component displaying a single document preview
struct DocumentRow: View {
    // MARK: Lifecycle

    init(document: Document, ndk: NDK) {
        self.document = document
        self.ndk = ndk
    }

    // MARK: Internal

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            NDKUIProfilePicture(ndk: ndk, pubkey: document.pubkey, size: 36)
            documentContent
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.background)
        .overlay(alignment: .bottom) {
            Divider()
                .padding(.leading, 64)
        }
    }

    // MARK: Private

    private let document: Document
    private let ndk: NDK

    private var hashtags: [String] {
        Array(document.hashtags.prefix(3))
    }

    private var documentContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            documentHeader
            titleView
            if let summary = document.summary, !summary.isEmpty {
                summaryView(summary)
            }
            bottomRow
        }
    }

    private var documentHeader: some View {
        HStack(spacing: 6) {
            Text(ndk.profile(for: document.pubkey).displayName)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)

            documentMetadata
        }
    }

    private var documentMetadata: some View {
        HStack(spacing: 4) {
            Image(systemName: "doc.text")
                .font(.caption)

            Text("Article")
                .font(.caption)

            Text("·")
                .font(.caption)

            Text(document.createdAt, style: .relative)
                .font(.caption)
        }
        .foregroundStyle(.secondary)
    }

    private var titleView: some View {
        Text(document.title)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.primary)
            .lineLimit(2)
    }

    private var bottomRow: some View {
        HStack(spacing: 12) {
            hashtagsList
            Spacer()
            readingTimeView
        }
        .padding(.top, 4)
    }

    @ViewBuilder
    private var hashtagsList: some View {
        if !hashtags.isEmpty {
            HStack(spacing: 8) {
                ForEach(hashtags, id: \.self) { tag in
                    HStack(spacing: 2) {
                        Image(systemName: "number")
                            .font(.caption2)
                        Text(tag)
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var readingTimeView: some View {
        HStack(spacing: 4) {
            Image(systemName: "clock")
                .font(.caption)
            Text("\(document.readingTimeMinutes) min")
                .font(.caption)
        }
        .foregroundStyle(.secondary)
    }

    private func summaryView(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .lineLimit(2)
    }
}
