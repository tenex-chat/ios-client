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

                if let toolCall = message.toolCall, let branch = toolCall.branch {
                    branchBadge(branch)
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

    private var debugInfoView: some View {
        HStack(spacing: 8) {
            Text("id:\(String(message.id.prefix(8)))")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }

    private var authorNameView: some View {
        Group {
            let isAgent = currentUserPubkey != nil && message.pubkey != currentUserPubkey

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
        Button {
            onTimestampTap?()
        } label: {
            Text(message.createdAt, style: .relative)
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)
        }
        .buttonStyle(.plain)
    }

    private var streamingIndicator: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(Color.blue)
                .frame(width: 6, height: 6)
                .opacity(cursorVisible ? 1 : 0.3)
                .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: cursorVisible)
                .onAppear { cursorVisible = true }

            Text("streaming...")
                .font(.system(size: 12))
                .foregroundStyle(.blue)
        }
    }

    private func branchBadge(_ branch: String) -> some View {
        Text(branch)
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(BranchColor.color(for: branch))
            .cornerRadius(6)
    }
}
