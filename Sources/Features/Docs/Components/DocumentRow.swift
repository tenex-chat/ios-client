//
// DocumentRow.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import NDKSwiftCore
import NDKSwiftUI
import SwiftUI

// MARK: - DocumentRow

/// Row component displaying a single document preview
struct DocumentRow: View {
    // MARK: Lifecycle

    init(document: NDKEvent, ndk: NDK) {
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
        .task {
            await loadAuthorMetadata()
        }
    }

    // MARK: Private

    @State private var metadata: NDKUserMetadata?

    private let document: NDKEvent
    private let ndk: NDK

    private var title: String {
        document.tagValue("title") ?? document.tagValue("name") ?? "Untitled"
    }

    private var summary: String? {
        document.tagValue("summary")
    }

    private var authorName: String {
        if let displayName = metadata?.displayName, !displayName.isEmpty {
            return displayName
        }
        if let name = metadata?.name, !name.isEmpty {
            return name
        }
        return String(document.pubkey.prefix(8)) + "..."
    }

    private var hashtags: [String] {
        document.tags(withName: "t")
            .compactMap { $0[safe: 1] }
            .prefix(3)
            .map { String($0) }
    }

    private var readingTime: String {
        let words = document.content
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: " ")
            .count
        let minutes = max(1, Int(ceil(Double(words) / 200.0)))
        return "\(minutes) min"
    }

    private var documentContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            documentHeader
            titleView
            if let summary, !summary.isEmpty {
                summaryView(summary)
            }
            bottomRow
        }
    }

    private var documentHeader: some View {
        HStack(spacing: 6) {
            Text(authorName)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.primary)

            documentMetadata
        }
    }

    private var documentMetadata: some View {
        HStack(spacing: 4) {
            Image(systemName: "doc.text")
                .font(.system(size: 11))

            Text("Article")
                .font(.system(size: 11))

            Text("·")
                .font(.system(size: 11))

            Text(Date(timeIntervalSince1970: TimeInterval(document.createdAt)), style: .relative)
                .font(.system(size: 11))
        }
        .foregroundStyle(.secondary)
    }

    private var titleView: some View {
        Text(title)
            .font(.system(size: 15, weight: .medium))
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

    @ViewBuilder private var hashtagsList: some View {
        if !hashtags.isEmpty {
            HStack(spacing: 8) {
                ForEach(hashtags, id: \.self) { tag in
                    HStack(spacing: 2) {
                        Image(systemName: "number")
                            .font(.system(size: 9))
                        Text(tag)
                            .font(.system(size: 10))
                    }
                    .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var readingTimeView: some View {
        HStack(spacing: 4) {
            Image(systemName: "clock")
                .font(.system(size: 10))
            Text(readingTime)
                .font(.system(size: 10))
        }
        .foregroundStyle(.secondary)
    }

    private func summaryView(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13))
            .foregroundStyle(.secondary)
            .lineLimit(2)
    }

    private func loadAuthorMetadata() async {
        for await meta in await ndk.profileManager.subscribe(for: document.pubkey) {
            metadata = meta
        }
    }
}
