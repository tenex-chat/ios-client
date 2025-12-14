//
// MessageHeaderView.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import NDKSwiftUI
import SwiftUI
import TENEXCore

// MARK: - MessageHeaderView

/// View for displaying message header with metadata badges
public struct MessageHeaderView: View {
    // MARK: Public

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if showDebugInfo {
                debugInfoView
            }

            HStack(spacing: 8) {
                authorNameView
                timestampView

                if let branch = message.branch {
                    branchBadge(branch)
                }

                if !message.pTaggedPubkeys.isEmpty {
                    pTaggedUsersView
                }

                if let phase = message.phase {
                    phaseBadge(phase)
                }

                if message.isStreaming {
                    streamingIndicator
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

    private var isAgent: Bool {
        currentUserPubkey != nil && message.pubkey != currentUserPubkey
    }

    private var debugInfoView: some View {
        HStack(spacing: 8) {
            Text("kind:\(message.kind)")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.secondary)
            Text("id:\(String(message.id.prefix(8)))")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }

    private var authorNameView: some View {
        Group {
            if let ndk {
                if isAgent, let onAgentTap {
                    Button(action: onAgentTap) {
                        NDKUIUsername(ndk: ndk, pubkey: message.pubkey)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.blue)
                    }
                    .buttonStyle(.plain)
                } else {
                    NDKUIUsername(ndk: ndk, pubkey: message.pubkey)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(isAgent ? .blue : .primary)
                }
            } else {
                Text(String(message.pubkey.prefix(8)))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)
            }
        }
    }

    private var timestampView: some View {
        Group {
            if let onTimestampTap {
                Button(action: onTimestampTap) {
                    Text(message.createdAt, style: .relative)
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            } else {
                Text(message.createdAt, style: .relative)
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var pTaggedUsersView: some View {
        HStack(spacing: -8) {
            ForEach(message.pTaggedPubkeys.prefix(3), id: \.self) { _ in
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 20, height: 20)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.gray)
                    )
            }
        }
    }

    private var streamingIndicator: some View {
        HStack(spacing: 4) {
            Text("typing")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Circle()
                .fill(Color.green)
                .frame(width: 6, height: 6)
                .opacity(cursorVisible ? 1 : 0.3)
                .onAppear {
                    withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                        cursorVisible = true
                    }
                }
        }
    }

    private func branchBadge(_ branch: String) -> some View {
        Text(branch)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(BranchColor.color(for: branch))
            .cornerRadius(4)
    }

    private func phaseBadge(_ phase: String) -> some View {
        Text(phase)
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(4)
    }
}
