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
            NDKUIProfilePicture(ndk: self.ndk, pubkey: self.document.pubkey, size: 36)
            self.documentContent
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
            await self.loadAuthorMetadata()
        }
    }

    // MARK: Private

    @State private var metadata: NDKUserMetadata?

    private let document: NDKEvent
    private let ndk: NDK

    private var title: String {
        self.document.tagValue("title") ?? self.document.tagValue("name") ?? "Untitled"
    }

    private var summary: String? {
        self.document.tagValue("summary")
    }

    private var authorName: String {
        if let displayName = metadata?.displayName, !displayName.isEmpty {
            return displayName
        }
        if let name = metadata?.name, !name.isEmpty {
            return name
        }
        return String(self.document.pubkey.prefix(8)) + "..."
    }

    private var hashtags: [String] {
        self.document.tags(withName: "t")
            .compactMap { $0[safe: 1] }
            .prefix(3)
            .map { String($0) }
    }

    private var readingTime: String {
        let words = self.document.content
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: " ")
            .count
        let minutes = max(1, Int(ceil(Double(words) / 200.0)))
        return "\(minutes) min"
    }

    private var documentContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            self.documentHeader
            self.titleView
            if let summary, !summary.isEmpty {
                self.summaryView(summary)
            }
            self.bottomRow
        }
    }

    private var documentHeader: some View {
        HStack(spacing: 6) {
            Text(self.authorName)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)

            self.documentMetadata
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

            Text(Date(timeIntervalSince1970: TimeInterval(self.document.createdAt)), style: .relative)
                .font(.caption)
        }
        .foregroundStyle(.secondary)
    }

    private var titleView: some View {
        Text(self.title)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.primary)
            .lineLimit(2)
    }

    private var bottomRow: some View {
        HStack(spacing: 12) {
            self.hashtagsList
            Spacer()
            self.readingTimeView
        }
        .padding(.top, 4)
    }

    @ViewBuilder private var hashtagsList: some View {
        if !self.hashtags.isEmpty {
            HStack(spacing: 8) {
                ForEach(self.hashtags, id: \.self) { tag in
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
            Text(self.readingTime)
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

    private func loadAuthorMetadata() async {
        for await meta in await self.ndk.profileManager.subscribe(for: self.document.pubkey) {
            self.metadata = meta
        }
    }
}
