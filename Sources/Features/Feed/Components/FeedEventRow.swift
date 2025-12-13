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
            NDKUIProfilePicture(ndk: ndk, pubkey: event.pubkey, size: 36)
            eventContent
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
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

    private let event: NDKEvent
    private let ndk: NDK

    private var authorName: String {
        if let displayName = metadata?.displayName, !displayName.isEmpty {
            return displayName
        }
        if let name = metadata?.name, !name.isEmpty {
            return name
        }
        return String(event.pubkey.prefix(8)) + "..."
    }

    private var eventDetails: (icon: String, label: String, title: String) {
        switch event.kind {
        case 1: // Text note
            let content = event.content.isEmpty ? "Note" : event.content
            return (
                icon: "bubble.left",
                label: "Note",
                title: content.count > 100 ? String(content.prefix(100)) + "..." : content
            )

        case 11: // Thread
            let title = event.tagValue("title") ?? "Thread"
            return (
                icon: "bubble.left.and.bubble.right",
                label: "Thread",
                title: title
            )

        case 30_023: // Long-form content
            let title = event.tagValue("title") ?? event.tagValue("name") ?? "Untitled"
            return (
                icon: "doc.text",
                label: "Article",
                title: title
            )

        case 1111: // Generic reply
            let content = event.content.isEmpty ? "Reply" : event.content
            return (
                icon: "bubble.left",
                label: "Reply",
                title: content.count > 100 ? String(content.prefix(100)) + "..." : content
            )

        case 29_000: // Call event
            let subject = event.tagValue("subject") ?? "Voice Call"
            return (
                icon: "phone",
                label: "Call",
                title: subject
            )

        case 1905,
             31_905: // Agent events
            let name = event.tagValue("name") ?? "Agent Activity"
            return (
                icon: "sparkles",
                label: "Agent",
                title: name
            )

        default:
            let content = event.content.isEmpty ? "Event" : event.content
            return (
                icon: "number",
                label: "Kind \(event.kind)",
                title: content.count > 100 ? String(content.prefix(100)) : content
            )
        }
    }

    private var hashtags: [String] {
        event.tags(withName: "t")
            .compactMap { $0[safe: 1] }
            .prefix(3)
            .map { String($0) }
    }

    private var eventContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            eventHeader
            eventTitle
            hashtagsList
        }
    }

    private var eventHeader: some View {
        HStack(spacing: 6) {
            Text(authorName)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.primary)

            eventMetadata
        }
    }

    private var eventMetadata: some View {
        HStack(spacing: 4) {
            Image(systemName: eventDetails.icon)
                .font(.system(size: 11))

            Text(eventDetails.label)
                .font(.system(size: 11))

            Text("·")
                .font(.system(size: 11))

            Text(Date(timeIntervalSince1970: TimeInterval(event.createdAt)), style: .relative)
                .font(.system(size: 11))
        }
        .foregroundStyle(.secondary)
    }

    private var eventTitle: some View {
        Text(eventDetails.title)
            .font(.system(size: 14))
            .foregroundStyle(.primary)
            .lineLimit(2)
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
            .padding(.top, 2)
        }
    }

    private func loadAuthorMetadata() async {
        for await meta in await ndk.profileManager.subscribe(for: event.pubkey) {
            metadata = meta
        }
    }
}
