//
// MessageHeaderView.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import NDKSwiftUI
import SwiftUI
import TENEXCore
import TENEXShared

// MARK: - MessageHeaderView

/// View for displaying message header with metadata badges
public struct MessageHeaderView: View {
    // MARK: Public

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if self.showDebugInfo {
                self.debugInfoView
            }

            HStack(spacing: 8) {
                self.authorNameView
                self.timestampView

                if let branch = message.branch {
                    self.branchBadge(branch)
                }

                if !self.message.pTaggedPubkeys.isEmpty {
                    self.pTaggedUsersView
                }

                if let phase = message.phase {
                    self.phaseBadge(phase)
                }

                if self.message.isStreaming {
                    self.streamingIndicator
                }
            }
        }
    }

    // MARK: Internal

    let message: Message
    let currentUserPubkey: String?
    let showDebugInfo: Bool
    let onAgentTap: (() -> Void)?
    let onTimestampTap: (() -> Void)?

    // MARK: Private

    @Environment(\.ndk) private var ndk

    @State private var cursorVisible = false
    @State private var currentTime = Date()

    private var isAgent: Bool {
        self.currentUserPubkey != nil && self.message.pubkey != self.currentUserPubkey
    }

    private var debugInfoView: some View {
        HStack(spacing: 8) {
            Text("kind:\(self.message.kind)")
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
            Text("id:\(String(self.message.id.prefix(8)))")
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
        }
    }

    private var authorNameView: some View {
        Group {
            if let ndk {
                if self.isAgent, let onAgentTap {
                    Button(action: onAgentTap) {
                        NDKUIUsername(ndk: ndk, pubkey: self.message.pubkey)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.blue)
                    }
                    .buttonStyle(.plain)
                } else {
                    NDKUIUsername(ndk: ndk, pubkey: self.message.pubkey)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(self.isAgent ? .blue : .primary)
                }
            } else {
                Text(String(self.message.pubkey.prefix(8)))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
            }
        }
    }

    private var timestampView: some View {
        Group {
            if let onTimestampTap {
                Button(action: onTimestampTap) {
                    Text(FormattingUtilities.relativeDiscrete(self.message.createdAt))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            } else {
                Text(FormattingUtilities.relativeDiscrete(self.message.createdAt))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .onAppear {
            // Start a timer that updates every minute
            Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
                self.currentTime = Date()
            }
        }
        .id(self.currentTime) // Force refresh when currentTime changes
    }

    private var pTaggedUsersView: some View {
        HStack(spacing: -8) {
            ForEach(self.message.pTaggedPubkeys.prefix(3), id: \.self) { _ in
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 20, height: 20)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.caption)
                            .foregroundStyle(.gray)
                    )
            }
        }
    }

    private var streamingIndicator: some View {
        HStack(spacing: 4) {
            Text("typing")
                .font(.caption)
                .foregroundStyle(.secondary)
            Circle()
                .fill(Color.green)
                .frame(width: 6, height: 6)
                .opacity(self.cursorVisible ? 1 : 0.3)
                .onAppear {
                    withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                        self.cursorVisible = true
                    }
                }
        }
    }

    private func branchBadge(_ branch: String) -> some View {
        Text(branch)
            .font(.caption.weight(.medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(BranchColor.color(for: branch))
            .cornerRadius(4)
    }

    private func phaseBadge(_ phase: String) -> some View {
        Text(phase)
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(4)
    }
}
