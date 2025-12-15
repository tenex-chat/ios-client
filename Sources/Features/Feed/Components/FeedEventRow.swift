//
// FeedEventRow.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import NDKSwiftCore
import NDKSwiftUI
import SwiftUI

// MARK: - FeedEventRow

/// Row component displaying a single feed event
struct FeedEventRow: View {
    // MARK: Lifecycle

    init(event: NDKEvent, ndk: NDK) {
        self.event = event
        self.ndk = ndk
    }

    // MARK: Internal

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            NDKUIProfilePicture(ndk: self.ndk, pubkey: self.event.pubkey, size: 36)
            self.eventContent
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

    private let event: NDKEvent
    private let ndk: NDK

    private var authorName: String {
        guard let author = ndk.getUser(event.pubkey) else {
            return String(self.event.pubkey.prefix(8)) + "..."
        }
        return author.profile?.displayName ?? String(self.event.pubkey.prefix(8)) + "..."
    }

    private var eventDetails: (icon: String, label: String, title: String) {
        switch self.event.kind {
        case 1: // Text note
            let content = self.event.content.isEmpty ? "Note" : self.event.content
            return (
                icon: "bubble.left",
                label: "Note",
                title: content.count > 100 ? String(content.prefix(100)) + "..." : content
            )

        case 11: // Thread
            let title = self.event.tagValue("title") ?? "Thread"
            return (
                icon: "bubble.left.and.bubble.right",
                label: "Thread",
                title: title
            )

        case 30_023: // Long-form content
            let title = self.event.tagValue("title") ?? self.event.tagValue("name") ?? "Untitled"
            return (
                icon: "doc.text",
                label: "Article",
                title: title
            )

        case 1111: // Generic reply
            let content = self.event.content.isEmpty ? "Reply" : self.event.content
            return (
                icon: "bubble.left",
                label: "Reply",
                title: content.count > 100 ? String(content.prefix(100)) + "..." : content
            )

        case 29_000: // Call event
            let subject = self.event.tagValue("subject") ?? "Voice Call"
            return (
                icon: "phone",
                label: "Call",
                title: subject
            )

        case 1905,
             31_905: // Agent events
            let name = self.event.tagValue("name") ?? "Agent Activity"
            return (
                icon: "sparkles",
                label: "Agent",
                title: name
            )

        default:
            let content = self.event.content.isEmpty ? "Event" : self.event.content
            return (
                icon: "number",
                label: "Kind \(self.event.kind)",
                title: content.count > 100 ? String(content.prefix(100)) : content
            )
        }
    }

    private var hashtags: [String] {
        self.event.tags(withName: "t")
            .compactMap { $0[safe: 1] }
            .prefix(3)
            .map { String($0) }
    }

    private var eventContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            self.eventHeader
            self.eventTitle
            self.hashtagsList
        }
    }

    private var eventHeader: some View {
        HStack(spacing: 6) {
            Text(self.authorName)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)

            self.eventMetadata
        }
    }

    private var eventMetadata: some View {
        HStack(spacing: 4) {
            Image(systemName: self.eventDetails.icon)
                .font(.caption)

            Text(self.eventDetails.label)
                .font(.caption)

            Text("·")
                .font(.caption)

            Text(Date(timeIntervalSince1970: TimeInterval(self.event.createdAt)), style: .relative)
                .font(.caption)
        }
        .foregroundStyle(.secondary)
    }

    private var eventTitle: some View {
        Text(self.eventDetails.title)
            .font(.subheadline)
            .foregroundStyle(.primary)
            .lineLimit(2)
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
            .padding(.top, 2)
        }
    }
}
