//
// MessagePublisher.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation
import NDKSwiftCore

// MARK: - MessagePublisher

/// Centralizes message publishing logic for both ChatViewModel and CallViewModel
///
/// This service provides unified methods for creating threads (kind:11) and replies (kind:1111)
/// with proper tag management, eliminating ViewModel dependencies on Views.
@MainActor
public final class MessagePublisher {
    // MARK: Lifecycle

    /// Initialize a new message publisher
    public init() {}

    // MARK: Public

    // MARK: - Thread Creation

    /// Publish a new thread (kind:11)
    /// - Parameters:
    ///   - ndk: NDK instance for publishing
    ///   - content: Message content
    ///   - projectRef: Project reference coordinate
    ///   - agentPubkey: Agent public key for routing
    ///   - mentions: Additional mentioned pubkeys
    ///   - nudges: Nudge IDs
    ///   - branch: Optional branch tag
    ///   - customTags: Additional custom tags (e.g., ["mode", "voice"])
    /// - Returns: Tuple of (published event, thread ID)
    public func publishThread(
        ndk: NDK,
        content: String,
        projectRef: String,
        agentPubkey: String,
        mentions: [String] = [],
        nudges: [String] = [],
        branch: String? = nil,
        customTags: [[String]] = []
    ) async throws -> (event: NDKEvent, threadID: String) {
        let builder = self.buildThreadTags(
            ndk: ndk,
            content: content,
            projectRef: projectRef,
            agentPubkey: agentPubkey,
            mentions: mentions,
            nudges: nudges,
            branch: branch,
            customTags: customTags
        )

        let (event, _) = try await ndk.publish { _ in builder }
        return (event, event.id)
    }

    // MARK: - Reply Creation

    /// Publish a reply (kind:1111)
    /// - Parameters:
    ///   - ndk: NDK instance for publishing
    ///   - threadEvent: Root thread event to reply to
    ///   - content: Message content
    ///   - projectRef: Project reference coordinate
    ///   - agentPubkey: Optional agent public key for routing
    ///   - mentions: Mentioned pubkeys
    ///   - replyTo: Optional parent message ID to reply to
    ///   - nudges: Nudge IDs
    ///   - branch: Optional branch tag
    ///   - customTags: Additional custom tags (e.g., ["mode", "voice"])
    /// - Returns: Published event
    public func publishReply(
        ndk: NDK,
        threadEvent: NDKEvent,
        content: String,
        projectRef: String,
        agentPubkey: String?,
        mentions: [String] = [],
        replyTo: String? = nil,
        nudges: [String] = [],
        branch: String? = nil,
        customTags: [[String]] = []
    ) async throws -> NDKEvent {
        let context = ReplyContext(
            projectRef: projectRef,
            replyTo: replyTo,
            agentPubkey: agentPubkey,
            mentions: mentions,
            selectedNudges: nudges,
            selectedBranch: branch,
            customTags: customTags
        )

        let (event, _) = try await ndk.publish { _ in
            self.buildReplyTags(
                builder: NDKEventBuilder.reply(to: threadEvent, ndk: ndk),
                content: content,
                context: context
            )
        }

        return event
    }

    // MARK: Private

    // MARK: - Private Tag Building

    // swiftlint:disable function_parameter_count
    /// Build tags for a new thread (kind:11)
    private nonisolated func buildThreadTags(
        ndk: NDK,
        content: String,
        projectRef: String,
        agentPubkey: String,
        mentions: [String],
        nudges: [String],
        branch: String?,
        customTags: [[String]]
    ) -> NDKEventBuilder {
        // swiftlint:enable function_parameter_count
        var builder = NDKEventBuilder(ndk: ndk)
            .kind(11)
            .content(content, extractImeta: false)

        // Add project reference (a tag)
        builder = builder.tag(["a", projectRef])

        // Add title tag (first 50 chars of content)
        let title = String(content.prefix(50))
        builder = builder.tag(["title", title])

        // Extract hashtags from content and add as t tags
        let pattern = "#(\\w+)"
        if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
            let range = NSRange(content.startIndex..., in: content)
            let matches = regex.matches(in: content, options: [], range: range)
            for match in matches {
                if let tagRange = Range(match.range(at: 1), in: content) {
                    let hashtag = String(content[tagRange]).lowercased()
                    builder = builder.tag(["t", hashtag])
                }
            }
        }

        // Add agent p-tag (required for new threads)
        builder = builder.tag(["p", agentPubkey])

        // Add mentioned p-tags (excluding agent if already added)
        for pubkey in mentions where pubkey != agentPubkey {
            builder = builder.tag(["p", pubkey])
        }

        // Add nudge tags
        for nudgeID in nudges {
            builder = builder.tag(["nudge", nudgeID])
        }

        // Add branch tag
        if let branch {
            builder = builder.tag(["branch", branch])
        }

        // Add custom tags (e.g., ["mode", "voice"])
        for customTag in customTags {
            builder = builder.tag(customTag)
        }

        return builder
    }

    /// Build tags for a reply message
    private nonisolated func buildReplyTags(
        builder: NDKEventBuilder,
        content: String,
        context: ReplyContext
    ) -> NDKEventBuilder {
        // Filter out auto p-tags only (keep e-tags from builder)
        let filteredTags = builder.tags.filter { $0.first != "p" }
        var newBuilder = builder.setTags(filteredTags)

        // Set content and project reference
        newBuilder = newBuilder.content(content, extractImeta: false)
        newBuilder = newBuilder.tag(["a", context.projectRef])

        // Add reply e-tag ONLY if replying to a specific message
        if let replyTo = context.replyTo {
            newBuilder = newBuilder.tag(["e", replyTo])
            // Don't add p-tag for replyTo author - it's handled below
        }

        // Add target agent p-tag for routing
        if let agentPubkey = context.agentPubkey {
            newBuilder = newBuilder.tag(["p", agentPubkey])
        }

        // Add mentioned user p-tags (excluding agent if already added)
        for pubkey in context.mentions where pubkey != context.agentPubkey {
            newBuilder = newBuilder.tag(["p", pubkey])
        }

        // Add nudge tags
        for nudgeID in context.selectedNudges {
            newBuilder = newBuilder.tag(["nudge", nudgeID])
        }

        // Add branch tag
        if let branch = context.selectedBranch {
            newBuilder = newBuilder.tag(["branch", branch])
        }

        // Add custom tags (e.g., ["mode", "voice"])
        for customTag in context.customTags {
            newBuilder = newBuilder.tag(customTag)
        }

        return newBuilder
    }
}

// MARK: - ReplyContext

/// Context for building reply tags
private struct ReplyContext {
    let projectRef: String
    let replyTo: String?
    let agentPubkey: String?
    let mentions: [String]
    let selectedNudges: [String]
    let selectedBranch: String?
    let customTags: [[String]]
}
